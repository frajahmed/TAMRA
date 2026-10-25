from profiles.models import Profile
from tracking.models import WeightLog


def sync_profile_weight(user) -> None:
    """Copy the newest weight into the profile and recalculate the targets.

    When the user deletes all weight entries, the profile keeps its last weight
    (otherwise the calorie target would disappear).
    """
    latest = WeightLog.objects.filter(user=user).order_by("-date").first()
    if latest is None:
        return
    profile, _created = Profile.objects.get_or_create(user=user)
    if profile.weight_kg == latest.weight_kg:
        return
    profile.weight_kg = latest.weight_kg
    profile.recalculate_targets()
    profile.save()
