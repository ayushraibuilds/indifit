from pydantic import BaseModel


class BackupSnapshotUploadRequest(BaseModel):
    snapshotId: str
    ciphertextBase64: str
    wrappedKeyBase64: str
    sha256Checksum: str
    byteSize: int
    schemaVersion: int
    backupFormatVersion: int
    deviceName: str
    isWeeklyMilestone: bool = False
