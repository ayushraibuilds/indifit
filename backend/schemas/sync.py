from typing import Any, Dict, List, Optional
from pydantic import BaseModel


class HlcModel(BaseModel):
    millis: int
    counter: int
    node_id: str


class SyncMutationModel(BaseModel):
    entity_id: str
    domain: str
    type: str  # insert, update, delete
    hlc: HlcModel
    payload: Optional[Dict[str, Any]] = None
    encrypted_envelope: Optional[Dict[str, Any]] = None


class SyncPushRequestModel(BaseModel):
    mutations: List[SyncMutationModel]


class SyncPushResponseModel(BaseModel):
    accepted_count: int
    server_received_hlc: HlcModel


class SyncPullResponseModel(BaseModel):
    mutations: List[SyncMutationModel]
    has_more: bool
    latest_hlc: Optional[HlcModel] = None
