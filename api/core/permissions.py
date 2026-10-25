from rest_framework import permissions


class IsOwner(permissions.BasePermission):
    """Object-level permission: only the owner may read or change an object.

    Health data is private, so unlike the classic IsOwnerOrReadOnly
    there is no public read access.
    """

    def has_object_permission(self, request, view, obj) -> bool:
        """Allow access only to the owner of the object."""
        return getattr(obj, "owner", None) == request.user
