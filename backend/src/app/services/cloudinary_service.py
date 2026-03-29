"""Shared Cloudinary-backed media upload service."""

from dataclasses import dataclass
from typing import Any

import cloudinary
import cloudinary.uploader
from fastapi import UploadFile
from starlette.concurrency import run_in_threadpool

from ..core.config import settings
from ..core.exceptions.http_exceptions import BadRequestException


@dataclass(frozen=True)
class MediaUploadResult:
    secure_url: str
    public_id: str
    resource_type: str
    bytes_uploaded: int | None = None
    original_filename: str | None = None
    format: str | None = None


class CloudinaryService:
    def __init__(
        self,
        *,
        cloud_name: str | None,
        api_key: str | None,
        api_secret: str | None,
        max_upload_bytes: int,
    ) -> None:
        self._cloud_name = cloud_name
        self._api_key = api_key
        self._api_secret = api_secret
        self._max_upload_bytes = max_upload_bytes

    @property
    def is_configured(self) -> bool:
        return bool(self._cloud_name and self._api_key and self._api_secret)

    async def upload_image(
        self,
        upload: UploadFile,
        *,
        folder: str,
    ) -> MediaUploadResult:
        payload = await self._read_and_validate_image(upload)
        if not self.is_configured:
            raise BadRequestException("Cloudinary media storage is not configured")

        upload_result = await run_in_threadpool(
            self._upload_payload,
            payload,
            upload.filename,
            folder,
        )

        secure_url = upload_result.get("secure_url")
        public_id = upload_result.get("public_id")
        resource_type = upload_result.get("resource_type")
        if not isinstance(secure_url, str) or not isinstance(public_id, str) or not isinstance(resource_type, str):
            raise BadRequestException("Cloudinary upload did not return a valid media reference")

        uploaded_bytes = upload_result.get("bytes")
        original_filename = upload_result.get("original_filename")
        file_format = upload_result.get("format")
        return MediaUploadResult(
            secure_url=secure_url,
            public_id=public_id,
            resource_type=resource_type,
            bytes_uploaded=uploaded_bytes if isinstance(uploaded_bytes, int) else None,
            original_filename=original_filename if isinstance(original_filename, str) else None,
            format=file_format if isinstance(file_format, str) else None,
        )

    async def _read_and_validate_image(self, upload: UploadFile) -> bytes:
        content_type = (upload.content_type or "").strip().lower()
        if not content_type.startswith("image/"):
            raise BadRequestException("Uploaded media must be an image")

        payload = await upload.read()
        if not payload:
            raise BadRequestException("Uploaded media file is empty")

        if len(payload) > self._max_upload_bytes:
            raise BadRequestException("Uploaded media exceeds the maximum allowed size")

        return payload

    def _upload_payload(
        self,
        payload: bytes,
        filename: str | None,
        folder: str,
    ) -> dict[str, Any]:
        cloudinary.config(
            cloud_name=self._cloud_name,
            api_key=self._api_key,
            api_secret=self._api_secret,
            secure=True,
        )
        return cloudinary.uploader.upload(
            payload,
            folder=folder,
            resource_type="image",
            filename_override=filename,
        )


cloudinary_service = CloudinaryService(
    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
    api_key=settings.CLOUDINARY_API_KEY,
    api_secret=settings.CLOUDINARY_API_SECRET.get_secret_value()
    if settings.CLOUDINARY_API_SECRET is not None
    else None,
    max_upload_bytes=settings.MEDIA_UPLOAD_MAX_BYTES,
)