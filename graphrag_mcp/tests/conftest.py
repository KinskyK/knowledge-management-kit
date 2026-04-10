import pytest
import tempfile
import shutil


@pytest.fixture
def tmp_working_dir():
    d = tempfile.mkdtemp(prefix="graphrag_test_")
    yield d
    shutil.rmtree(d, ignore_errors=True)


@pytest.fixture
def sample_kg():
    return {
        "entities": [
            {
                "entity_name": "FAR Protocol",
                "entity_type": "concept",
                "description": "Proactive semantic context management with HOT/WARM/COLD layers.",
                "source_id": "meta/decisions/core/CORE-01.md",
            },
            {
                "entity_name": "sessions.md",
                "entity_type": "file",
                "description": "Session context storage, separate from roadmap.",
                "source_id": "meta/decisions/core/CORE-02.md",
            },
        ],
        "relationships": [
            {
                "src_id": "FAR Protocol",
                "tgt_id": "sessions.md",
                "description": "WARM residual from FAR audit is written to sessions.md.",
                "keywords": "depends-on, writes-to",
                "weight": 0.9,
                "source_id": "meta/decisions/core/CORE-01.md",
            },
        ],
        "chunks": [
            {
                "content": "FAR Protocol manages context: HOT (active, max 3-5), WARM (archive), COLD (discard).",
                "source_id": "meta/decisions/core/CORE-01.md",
            },
            {
                "content": "Sessions.md stores session context separately from roadmap.",
                "source_id": "meta/decisions/core/CORE-02.md",
            },
        ],
    }
