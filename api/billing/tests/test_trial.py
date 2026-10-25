from datetime import timedelta
from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from accounts.data import delete_account
from billing.models import TrialClaim
from billing.trial import (
    check_trial,
    claim_trial,
    identity_hash,
    is_disposable,
    normalize_email,
)

User = get_user_model()


class NormalizeEmailTests(TestCase):
    def test_cases(self):
        cases = {
            "Max.Muster+trial@GoogleMail.com": "maxmuster@gmail.com",
            "m.a.x@gmail.com": "max@gmail.com",
            " Anna+x@web.de ": "anna@web.de",
            "anna.b@web.de": "anna.b@web.de",  # dots matter outside Gmail
            "no-at-sign": "no-at-sign",
        }
        for raw, expected in cases.items():
            self.assertEqual(normalize_email(raw), expected, raw)


class IdentityHashTests(TestCase):
    def test_hash_is_hmac_sha256_and_reveals_nothing(self):
        value = identity_hash("email", "max@gmail.com")
        self.assertEqual(len(value), 64)
        self.assertNotIn("max", value)
        self.assertEqual(value, identity_hash("email", "max@gmail.com"))
        self.assertNotEqual(value, identity_hash("device", "max@gmail.com"))

    def test_hash_depends_on_the_secret_key(self):
        with override_settings(TRIAL_HASH_KEY="key-one"):
            one = identity_hash("email", "max@gmail.com")
        with override_settings(TRIAL_HASH_KEY="key-two"):
            two = identity_hash("email", "max@gmail.com")
        self.assertNotEqual(one, two)


class TrialRulesTests(TestCase):
    def test_first_trial_allowed_second_blocked(self):
        self.assertTrue(claim_trial("max@gmail.com").eligible)
        self.assertEqual(check_trial("max@gmail.com").reason, "already_used")

    def test_email_tricks_do_not_give_a_new_trial(self):
        claim_trial("max.muster@gmail.com")
        for variant in (
            "MaxMuster@gmail.com",
            "max.muster+2@googlemail.com",
            "m.axmuster@gmail.com",
        ):
            self.assertFalse(check_trial(variant).eligible, variant)

    def test_same_device_with_new_email_is_blocked(self):
        claim_trial("a@example.com", device_id="device-123")
        result = check_trial("b@example.com", device_id="device-123")
        self.assertEqual(result.reason, "already_used")
        self.assertTrue(check_trial("b@example.com", device_id="device-456").eligible)

    def test_disposable_email(self):
        self.assertTrue(is_disposable("x@mailinator.com"))
        self.assertFalse(is_disposable("x@gmail.com"))
        self.assertEqual(claim_trial("x@yopmail.com").reason, "disposable_email")
        self.assertEqual(TrialClaim.objects.count(), 0)

    @override_settings(DISPOSABLE_EMAIL_DOMAINS=["wegwerf.de"])
    def test_extra_disposable_domains_from_settings(self):
        self.assertTrue(is_disposable("x@wegwerf.de"))

    def test_only_hashes_are_stored(self):
        claim_trial("max@gmail.com", device_id="device-123")
        stored = " ".join(TrialClaim.objects.values_list("identity_hash", flat=True))
        self.assertNotIn("max", stored)
        self.assertNotIn("device-123", stored)
        self.assertEqual(TrialClaim.objects.count(), 2)

    def test_account_deletion_does_not_reset_the_trial(self):
        user = User.objects.create_user(email="max@gmail.com", password="x")
        claim_trial(user.email)
        delete_account(user)
        User.objects.create_user(email="max@gmail.com", password="x")
        self.assertFalse(check_trial("max@gmail.com").eligible)

    def test_old_claims_are_purged(self):
        claim_trial("old@example.com")
        TrialClaim.objects.update(created_at=timezone.now() - timedelta(days=800))
        claim_trial("new@example.com")
        out = StringIO()
        call_command("purge_trial_claims", stdout=out)
        self.assertIn("Deleted 1", out.getvalue())
        self.assertTrue(check_trial("old@example.com").eligible)
        self.assertFalse(check_trial("new@example.com").eligible)


class TrialApiTests(APITestCase):
    url = reverse("me-trial")

    def setUp(self):
        self.user = User.objects.create_user(email="max@gmail.com", password="x")
        self.client.force_authenticate(self.user)

    def test_requires_login(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get(self.url).status_code, 401)

    def test_check_then_claim_then_blocked(self):
        self.assertEqual(self.client.get(self.url).data, {"eligible": True, "reason": ""})
        response = self.client.post(self.url, {"device_id": "ios-abc"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        again = self.client.post(self.url, {"device_id": "ios-abc"}, format="json")
        self.assertEqual(again.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(again.data["reason"], "already_used")

    def test_device_check_via_query(self):
        claim_trial("other@example.com", device_id="ios-abc")
        response = self.client.get(self.url, {"device_id": "ios-abc"})
        self.assertEqual(response.data, {"eligible": False, "reason": "already_used"})
