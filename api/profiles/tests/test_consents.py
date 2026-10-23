from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.reverse import reverse
from rest_framework.test import APITestCase

from profiles.models import Consent

User = get_user_model()


class ConsentApiTests(APITestCase):
    url = reverse("me-consents")

    def setUp(self):
        self.user = User.objects.create_user(email="a@example.com", password="x")
        self.other = User.objects.create_user(email="b@example.com", password="x")
        self.client.force_authenticate(self.user)

    def give(self, consent_type: str = "health_data"):
        return self.client.post(
            self.url, {"type": consent_type, "version": "2026-10"}, format="json"
        )

    def withdraw_url(self, consent_type: str = "health_data") -> str:
        return reverse("me-consent-withdraw", kwargs={"consent_type": consent_type})

    def test_requires_login(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get(self.url).status_code, status.HTTP_401_UNAUTHORIZED)

    def test_give_and_list_own_only(self):
        response = self.give()
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["type"], "health_data")
        self.assertIsNone(response.data["withdrawn_at"])
        Consent.objects.create(user=self.other, type="terms", version="1")

        listed = self.client.get(self.url)
        self.assertEqual(listed.status_code, status.HTTP_200_OK)
        self.assertEqual(len(listed.data), 1)

    def test_unknown_type(self):
        response = self.give("selling_data")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("type", response.data["fields"])

    def test_withdraw(self):
        self.give()
        response = self.client.post(self.withdraw_url())
        self.assertEqual(response.data, {"withdrawn": 1})
        consent = Consent.objects.get(user=self.user)
        self.assertIsNotNone(consent.withdrawn_at)
        # second withdraw: nothing active anymore
        self.assertEqual(self.client.post(self.withdraw_url()).data, {"withdrawn": 0})

    def test_withdraw_unknown_type(self):
        response = self.client.post(self.withdraw_url("nope"))
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_cannot_withdraw_other_users_consent(self):
        Consent.objects.create(user=self.other, type="health_data", version="1")
        self.assertEqual(self.client.post(self.withdraw_url()).data, {"withdrawn": 0})
        self.assertIsNone(Consent.objects.get(user=self.other).withdrawn_at)

    def test_no_delete(self):
        response = self.client.delete(self.url)
        self.assertEqual(response.status_code, status.HTTP_405_METHOD_NOT_ALLOWED)
