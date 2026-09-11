import base64
from typing import Any, Dict
from fastapi import HTTPException
import httpx
from backend.core.config import AI_MODEL, get_gemini_api_key


async def query_gemini_text(prompt: str, json_mode: bool = False) -> str:
    gemini_key = get_gemini_api_key()
    if not gemini_key:
        raise ValueError("Missing GEMINI_API_KEY env variable")

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{AI_MODEL}:generateContent?key={gemini_key}"

    headers = {"Content-Type": "application/json"}
    payload: Dict[str, Any] = {
        "contents": [{"parts": [{"text": prompt}]}],
    }

    if json_mode:
        payload["generationConfig"] = {
            "responseMimeType": "application/json"
        }

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(url, headers=headers, json=payload)
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail=f"Gemini API Error: {response.text}")

        data = response.json()
        try:
            return data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError):
            raise HTTPException(status_code=500, detail="Malformed response from Gemini API")


async def query_gemini_vision(prompt: str, image_bytes: bytes, mime_type: str) -> str:
    gemini_key = get_gemini_api_key()
    if not gemini_key:
        raise ValueError("Missing GEMINI_API_KEY env variable")

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{AI_MODEL}:generateContent?key={gemini_key}"

    headers = {"Content-Type": "application/json"}
    base64_image = base64.b64encode(image_bytes).decode("utf-8")

    payload: Dict[str, Any] = {
        "contents": [
            {
                "parts": [
                    {"text": prompt},
                    {
                        "inlineData": {
                            "mimeType": mime_type,
                            "data": base64_image,
                        }
                    },
                ]
            }
        ],
        "generationConfig": {
            "responseMimeType": "application/json"
        },
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(url, headers=headers, json=payload)
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail=f"Gemini API Error: {response.text}")

        data = response.json()
        try:
            return data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError):
            raise HTTPException(status_code=500, detail="Malformed response from Gemini API")
