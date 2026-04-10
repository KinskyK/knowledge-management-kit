import os
from dataclasses import dataclass
from pathlib import Path
import yaml


@dataclass
class GraphRAGConfig:
    working_dir: str = ".graphrag/data"
    embedding_model: str = "intfloat/multilingual-e5-large"
    embedding_dim: int = 1024
    max_token_size: int = 512
    openrouter_api_key: str = ""
    openrouter_model: str = "google/gemma-3-12b-it:free"
    openrouter_base_url: str = "https://openrouter.ai/api/v1"


def load_config(config_path: str | None = None) -> GraphRAGConfig:
    config = GraphRAGConfig()

    yaml_path = config_path or os.environ.get(
        "GRAPHRAG_CONFIG", ".graphrag/config.yaml"
    )
    if os.path.exists(yaml_path):
        with open(yaml_path) as f:
            data = yaml.safe_load(f) or {}
        for key, value in data.items():
            if hasattr(config, key):
                setattr(config, key, value)

    env_map = {
        "GRAPHRAG_WORKING_DIR": "working_dir",
        "GRAPHRAG_EMBEDDING_MODEL": "embedding_model",
        "OPENROUTER_API_KEY": "openrouter_api_key",
        "OPENROUTER_MODEL": "openrouter_model",
    }
    for env_key, attr in env_map.items():
        val = os.environ.get(env_key)
        if val:
            setattr(config, attr, val)

    return config
