import pytest
from unittest.mock import AsyncMock, MagicMock, patch


@pytest.mark.asyncio
async def test_llm_returns_string():
    from graphrag_mcp.llm import create_llm_func

    llm_fn = create_llm_func(api_key="test", model="test-model")

    with patch("graphrag_mcp.llm.httpx.AsyncClient") as MockClient:
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "choices": [{"message": {"content": "test response"}}]
        }
        mock_response.raise_for_status = MagicMock()

        mock_client_instance = AsyncMock()
        mock_client_instance.post.return_value = mock_response
        mock_client_instance.__aenter__ = AsyncMock(return_value=mock_client_instance)
        mock_client_instance.__aexit__ = AsyncMock(return_value=False)
        MockClient.return_value = mock_client_instance

        result = await llm_fn("summarize this")

        assert result == "test response"


@pytest.mark.asyncio
async def test_llm_without_api_key_returns_empty():
    from graphrag_mcp.llm import create_llm_func

    llm_fn = create_llm_func(api_key="", model="test-model")
    result = await llm_fn("anything")

    assert result == ""
