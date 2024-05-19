import time
from datetime import datetime, timedelta, timezone
import json
import traceback
from typing import Callable
import logging
import sys
from pythonjsonlogger import jsonlogger
from fastapi import Request, Response
from fastapi.routing import APIRoute
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException


logger = logging.getLogger(__name__)
handler = logging.StreamHandler(sys.stdout)
json_fmt = jsonlogger.JsonFormatter(fmt="%(asctime)s %(levelname)s %(name)s %(message)s", json_ensure_ascii=False)
handler.setFormatter(json_fmt)
logger.addHandler(handler)
logger.setLevel(logging.DEBUG)

JST = timezone(timedelta(hours=+9), "JST")


class LoggingContextRoute(APIRoute):
    def get_route_handler(self) -> Callable:
        original_route_handler = super().get_route_handler()

        async def custom_route_handler(request: Request) -> Response:
            response = None
            record = {}
            await self._logging_request(request, record)

            # 処理にかかる時間を計測
            before = time.time()

            response = await self._execute_request(request, original_route_handler, record)
            duration = round(time.time() - before, 4)
            time_local = datetime.fromtimestamp(before, JST)
            record["time_jp"] = time_local.isoformat(timespec="milliseconds")
            record["request_time"] = str(duration)
            await self._logging_response(response, record)
            if response.status_code == 200:
                logger.info(record)
            else:
                logger.error(record)
            return response

        return custom_route_handler

    async def _execute_request(self, request: Request, route_handler: Callable, record: dict) -> Response:
        try:
            response: Response = await route_handler(request)
        except StarletteHTTPException as exc:
            record["error"] = exc.detail
            record["status"] = exc.status_code
            record["traceback"] = traceback.format_exc().splitlines()
            raise
        except RequestValidationError as exc:
            record["error"] = exc.errors()
            record["traceback"] = traceback.format_exc().splitlines()
            raise
        return response

    async def _logging_response(self, response: Response, record: dict) -> Response | None:
        if response is None:
            return
        try:
            record["response_body"] = json.loads(response.body.decode("utf-8"))
        except json.JSONDecodeError:
            record["response_body"] = response.body.decode("utf-8")
        record["status"] = response.status_code
        record["response_headers"] = {k.decode("utf-8"): v.decode("utf-8") for (k, v) in response.headers.raw}

    async def _logging_request(self, request: Request, record: dict) -> Response | None:
        if await request.body():
            try:
                record["request_body"] = await request.json()
            except json.JSONDecodeError:
                record["request_body"] = (await request.body()).decode("utf-8")
        record["request_headers"] = {k.decode("utf-8"): v.decode("utf-8") for (k, v) in request.headers.raw}
        record["remote_addr"] = request.client.host
        record["request_uri"] = request.url.path
        record["request_method"] = request.method
