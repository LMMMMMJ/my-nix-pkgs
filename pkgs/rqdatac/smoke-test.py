"""在无凭据、无网络的构建环境验证 RQData 安装及传输编解码。"""

import sys
from datetime import date, datetime
from decimal import Decimal
from importlib.metadata import version

import rqdatac
from rqdatac.connection import Connection
from rqdatac.share.codec import pack_one, unpack_header, unpack_one
from rqdatac.share.protocol import (
    COMPRESSION_METHOD,
    HEADER_LENGTH,
    MSG_TYPE,
    SERIALIZATION_TYPE,
)

assert rqdatac.__version__ == version("rqdatac") == sys.argv[1]
assert callable(Connection)
assert not rqdatac.initialized()
for name in (
    "get_price",
    "get_pit_financials_ex",
    "current_performance",
    "performance_forecast",
):
    assert callable(getattr(rqdatac, name)), name

payload = {
    "order_book_id": "000001.XSHE",
    "date": date(2026, 10, 30),
    "published_at": datetime(2026, 10, 30, 9, 15),
    "value": Decimal("12345.67"),
    "rows": list(range(1024)),
}
cases = 0
for serialization in (SERIALIZATION_TYPE.JSON, SERIALIZATION_TYPE.MSGPACK):
    for compression in (
        COMPRESSION_METHOD.NONE,
        COMPRESSION_METHOD.ZLIB,
        COMPRESSION_METHOD.BROTLI,
        COMPRESSION_METHOD.ZSTD,
    ):
        frame = pack_one(
            payload, MSG_TYPE.RESPONSE, serialization, compression, force_compress=True
        )
        kind, st, cm, length = unpack_header(frame[:HEADER_LENGTH])
        body = frame[HEADER_LENGTH:]
        assert (kind, st, cm, length) == (
            MSG_TYPE.RESPONSE,
            serialization,
            compression,
            len(body),
        )
        assert unpack_one(body, st, cm) == payload
        cases += 1
print(
    f"rqdatac {rqdatac.__version__}: native import, public APIs and "
    f"{cases} codec round trips passed"
)
