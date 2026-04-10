import httpx


def create_llm_func(
    api_key: str = "",
    model: str = "google/gemma-3-12b-it:free",
    base_url: str = "https://openrouter.ai/api/v1",
):
    async def _llm(prompt: str, **kwargs) -> str:
        if not api_key:
            return ""

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": model,
                    "messages": [{"role": "user", "content": prompt}],
                },
                timeout=60.0,
            )
            response.raise_for_status()
            return response.json()["choices"][0]["message"]["content"]

    return _llm
