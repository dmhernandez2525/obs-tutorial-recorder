"""
OBS WebSocket client for Windows.
Communicates with OBS Studio via WebSocket on port 4455.
"""

import asyncio
import json
from typing import Any, Callable, Dict, List, Optional, TYPE_CHECKING
from dataclasses import dataclass

try:
    import websockets
    from websockets.client import WebSocketClientProtocol
except ImportError:
    websockets = None
    WebSocketClientProtocol = None

from ..utils.logger import log_info, log_error, log_warning, log_debug


OBS_WEBSOCKET_URL = "ws://localhost:4455"
RPC_VERSION = 1

# OBS Event Types (commonly used)
EVENT_RECORDING_STARTED = "RecordStateChanged"
EVENT_RECORDING_STOPPED = "RecordStateChanged"
EVENT_SCENE_CHANGED = "CurrentProgramSceneChanged"
EVENT_SOURCE_CREATED = "InputCreated"
EVENT_SOURCE_REMOVED = "InputRemoved"
EVENT_PROFILE_CHANGED = "CurrentProfileChanged"


@dataclass
class OBSEvent:
    """Represents an OBS WebSocket event."""
    event_type: str
    event_data: Dict[str, Any]


@dataclass
class OBSResponse:
    """Response from OBS WebSocket."""
    success: bool
    request_type: str
    request_id: str
    data: Dict[str, Any]
    error_code: Optional[int] = None
    error_message: Optional[str] = None


class OBSWebSocket:
    """
    Async WebSocket client for OBS Studio.
    Handles all OBS communication via WebSocket protocol.
    """

    def __init__(self, url: str = OBS_WEBSOCKET_URL):
        self.url = url
        self._ws: Optional[WebSocketClientProtocol] = None
        self._connected = False
        self._request_id = 0
        self._event_callbacks: Dict[str, List[Callable[[OBSEvent], None]]] = {}
        self._global_event_callbacks: List[Callable[[OBSEvent], None]] = []

    def add_event_callback(self, event_type: str, callback: Callable[[OBSEvent], None]):
        """Register a callback for a specific event type."""
        if event_type not in self._event_callbacks:
            self._event_callbacks[event_type] = []
        self._event_callbacks[event_type].append(callback)

    def add_global_event_callback(self, callback: Callable[[OBSEvent], None]):
        """Register a callback for all events."""
        self._global_event_callbacks.append(callback)

    def remove_event_callback(self, event_type: str, callback: Callable[[OBSEvent], None]):
        """Remove an event callback."""
        if event_type in self._event_callbacks:
            try:
                self._event_callbacks[event_type].remove(callback)
            except ValueError:
                pass

    def _handle_event(self, event_type: str, event_data: Dict[str, Any]):
        """Process an event and call registered callbacks."""
        event = OBSEvent(event_type=event_type, event_data=event_data)

        # Call specific callbacks
        if event_type in self._event_callbacks:
            for callback in self._event_callbacks[event_type]:
                try:
                    callback(event)
                except Exception as e:
                    log_warning(f"[WS] Event callback error: {e}")

        # Call global callbacks
        for callback in self._global_event_callbacks:
            try:
                callback(event)
            except Exception as e:
                log_warning(f"[WS] Global event callback error: {e}")

    @property
    def connected(self) -> bool:
        return self._connected and self._ws is not None

    def _next_request_id(self) -> str:
        self._request_id += 1
        return f"req_{self._request_id}"

    async def connect(self, max_retries: int = 30, retry_delay: float = 1.0) -> bool:
        """
        Connect to OBS WebSocket with retry logic.
        Returns True if connected successfully.
        """
        if websockets is None:
            log_error("websockets library not installed. Run: pip install websockets")
            return False

        log_info(f"Attempting to connect to OBS WebSocket at {self.url}")

        for attempt in range(max_retries):
            try:
                log_debug(f"[WS] Connection attempt {attempt + 1}/{max_retries} to {self.url}")
                self._ws = await asyncio.wait_for(
                    websockets.connect(self.url),
                    timeout=5.0
                )
                log_debug(f"[WS] WebSocket connection established, waiting for Hello...")

                # Wait for Hello message (op=0)
                hello = await asyncio.wait_for(self._ws.recv(), timeout=5.0)
                hello_data = json.loads(hello)
                log_debug(f"[WS] Received: op={hello_data.get('op')} (Hello={hello_data.get('op')==0})")

                if hello_data.get("op") == 0:
                    obs_version = hello_data.get("d", {}).get("obsWebSocketVersion", "unknown")
                    log_debug(f"[WS] OBS WebSocket version: {obs_version}")

                    # Send Identify message (op=1)
                    identify = {"op": 1, "d": {"rpcVersion": RPC_VERSION}}
                    await self._ws.send(json.dumps(identify))
                    log_debug(f"[WS] Sent Identify with rpcVersion={RPC_VERSION}")

                    # Wait for Identified response (op=2)
                    identified = await asyncio.wait_for(self._ws.recv(), timeout=5.0)
                    identified_data = json.loads(identified)
                    log_debug(f"[WS] Received: op={identified_data.get('op')} (Identified={identified_data.get('op')==2})")

                    if identified_data.get("op") == 2:
                        self._connected = True
                        negotiated_version = identified_data.get("d", {}).get("negotiatedRpcVersion", "unknown")
                        log_info(f"[WS] Connected to OBS WebSocket (RPC v{negotiated_version})")
                        return True
                    else:
                        log_warning(f"[WS] Expected Identified (op=2), got op={identified_data.get('op')}")

                log_warning(f"[WS] Unexpected response during handshake: {hello_data}")

            except asyncio.TimeoutError:
                log_debug(f"[WS] Attempt {attempt + 1} timed out waiting for response")
            except ConnectionRefusedError:
                log_debug(f"[WS] Attempt {attempt + 1} refused - OBS not running or WebSocket disabled?")
            except OSError as e:
                log_debug(f"[WS] Attempt {attempt + 1} OS error: {e}")
            except Exception as e:
                log_warning(f"[WS] Attempt {attempt + 1} error: {type(e).__name__}: {e}")

            if attempt < max_retries - 1:
                log_debug(f"[WS] Waiting {retry_delay}s before retry...")
                await asyncio.sleep(retry_delay)

        log_error(f"[WS] Failed to connect to OBS after {max_retries} attempts")
        log_error("[WS] ")
        log_error("[WS] ====== OBS WebSocket NOT ENABLED ======")
        log_error("[WS] Please enable WebSocket in OBS:")
        log_error("[WS] 1. Open OBS Studio")
        log_error("[WS] 2. Go to Tools > WebSocket Server Settings")
        log_error("[WS] 3. Check 'Enable WebSocket Server'")
        log_error("[WS] 4. Uncheck 'Enable Authentication'")
        log_error("[WS] 5. Port should be 4455 (default)")
        log_error("[WS] 6. Click OK and restart OBS")
        log_error("[WS] =========================================")
        return False

    async def disconnect(self):
        """Disconnect from OBS WebSocket."""
        if self._ws:
            try:
                await self._ws.close()
            except Exception:
                pass
            self._ws = None
            self._connected = False
            log_info("Disconnected from OBS WebSocket")

    async def send_request(
        self,
        request_type: str,
        request_data: Optional[Dict[str, Any]] = None,
        timeout: float = 10.0
    ) -> OBSResponse:
        """
        Send a request to OBS and wait for response.
        """
        if not self.connected:
            log_error(f"[WS] Cannot send {request_type}: Not connected to OBS")
            return OBSResponse(
                success=False,
                request_type=request_type,
                request_id="",
                data={},
                error_message="Not connected to OBS"
            )

        request_id = self._next_request_id()

        # Build request message (op=6)
        message = {
            "op": 6,
            "d": {
                "requestType": request_type,
                "requestId": request_id,
            }
        }
        if request_data:
            message["d"]["requestData"] = request_data

        try:
            msg_json = json.dumps(message)
            log_debug(f"[WS] >>> {request_type} ({request_id})")
            if request_data:
                log_debug(f"[WS]     Data: {json.dumps(request_data)[:200]}")
            await self._ws.send(msg_json)

            # Wait for response
            while True:
                response = await asyncio.wait_for(self._ws.recv(), timeout=timeout)
                response_data = json.loads(response)

                # Check if this is our response (op=7)
                if response_data.get("op") == 7:
                    d = response_data.get("d", {})
                    if d.get("requestId") == request_id:
                        status = d.get("requestStatus", {})
                        success = status.get("result", False)

                        resp = OBSResponse(
                            success=success,
                            request_type=request_type,
                            request_id=request_id,
                            data=d.get("responseData", {}),
                            error_code=status.get("code") if not success else None,
                            error_message=status.get("comment") if not success else None,
                        )

                        if success:
                            log_debug(f"[WS] <<< {request_type}: OK")
                        else:
                            log_warning(f"[WS] <<< {request_type}: FAILED ({resp.error_code}: {resp.error_message})")

                        return resp
                else:
                    # Event or other message, process and continue waiting
                    op = response_data.get("op")
                    if op == 5:  # Event
                        event_data = response_data.get("d", {})
                        event_type = event_data.get("eventType", "unknown")
                        log_debug(f"[WS] Event: {event_type}")
                        # Process event through callback system
                        self._handle_event(event_type, event_data.get("eventData", {}))

        except asyncio.TimeoutError:
            log_error(f"[WS] Request {request_type} timed out after {timeout}s")
            return OBSResponse(
                success=False,
                request_type=request_type,
                request_id=request_id,
                data={},
                error_message="Request timed out"
            )
        except Exception as e:
            log_error(f"[WS] Request {request_type} failed: {type(e).__name__}: {e}")
            return OBSResponse(
                success=False,
                request_type=request_type,
                request_id=request_id,
                data={},
                error_message=str(e)
            )

    # Profile Management

    async def get_profile_list(self) -> OBSResponse:
        """Get list of all profiles and current profile."""
        return await self.send_request("GetProfileList")

    async def get_current_profile(self) -> Optional[str]:
        """Get the current profile name."""
        response = await self.get_profile_list()
        if response.success:
            return response.data.get("currentProfileName")
        return None

    async def set_current_profile(self, profile_name: str) -> OBSResponse:
        """Switch to a different profile."""
        return await self.send_request("SetCurrentProfile", {"profileName": profile_name})

    async def create_profile(self, profile_name: str) -> OBSResponse:
        """Create a new profile."""
        return await self.send_request("CreateProfile", {"profileName": profile_name})

    # Scene Management

    async def get_scene_list(self) -> OBSResponse:
        """Get list of all scenes."""
        return await self.send_request("GetSceneList")

    async def get_current_program_scene(self) -> Optional[str]:
        """Get the current program scene name."""
        response = await self.send_request("GetCurrentProgramScene")
        if response.success:
            return response.data.get("currentProgramSceneName")
        return None

    async def set_current_program_scene(self, scene_name: str) -> OBSResponse:
        """Switch to a different scene."""
        return await self.send_request("SetCurrentProgramScene", {"sceneName": scene_name})

    async def create_scene(self, scene_name: str) -> OBSResponse:
        """Create a new scene."""
        return await self.send_request("CreateScene", {"sceneName": scene_name})

    async def get_scene_item_list(self, scene_name: str) -> OBSResponse:
        """Get list of items in a scene."""
        return await self.send_request("GetSceneItemList", {"sceneName": scene_name})

    async def remove_scene_item(self, scene_name: str, scene_item_id: int) -> OBSResponse:
        """Remove an item from a scene."""
        return await self.send_request("RemoveSceneItem", {
            "sceneName": scene_name,
            "sceneItemId": scene_item_id
        })

    # Input/Source Management

    async def get_input_list(self, input_kind: Optional[str] = None) -> OBSResponse:
        """Get list of all inputs, optionally filtered by kind."""
        data = {}
        if input_kind:
            data["inputKind"] = input_kind
        return await self.send_request("GetInputList", data if data else None)

    async def get_input_kind_list(self) -> OBSResponse:
        """Get list of all available input kinds."""
        return await self.send_request("GetInputKindList")

    async def create_input(
        self,
        scene_name: str,
        input_name: str,
        input_kind: str,
        input_settings: Optional[Dict[str, Any]] = None,
        scene_item_enabled: bool = True
    ) -> OBSResponse:
        """Create a new input/source in a scene."""
        data = {
            "sceneName": scene_name,
            "inputName": input_name,
            "inputKind": input_kind,
            "sceneItemEnabled": scene_item_enabled,
        }
        if input_settings:
            data["inputSettings"] = input_settings
        return await self.send_request("CreateInput", data)

    async def get_input_settings(self, input_name: str) -> OBSResponse:
        """Get settings for an input."""
        return await self.send_request("GetInputSettings", {"inputName": input_name})

    async def set_input_settings(
        self,
        input_name: str,
        input_settings: Dict[str, Any],
        overlay: bool = True
    ) -> OBSResponse:
        """Set settings for an input."""
        return await self.send_request("SetInputSettings", {
            "inputName": input_name,
            "inputSettings": input_settings,
            "overlay": overlay
        })

    # Filter Management

    async def get_source_filter_list(self, source_name: str) -> OBSResponse:
        """Get list of filters on a source."""
        return await self.send_request("GetSourceFilterList", {"sourceName": source_name})

    async def create_source_filter(
        self,
        source_name: str,
        filter_name: str,
        filter_kind: str,
        filter_settings: Optional[Dict[str, Any]] = None
    ) -> OBSResponse:
        """Create a filter on a source."""
        data = {
            "sourceName": source_name,
            "filterName": filter_name,
            "filterKind": filter_kind,
        }
        if filter_settings:
            data["filterSettings"] = filter_settings
        return await self.send_request("CreateSourceFilter", data)

    async def set_source_filter_settings(
        self,
        source_name: str,
        filter_name: str,
        filter_settings: Dict[str, Any],
        overlay: bool = True
    ) -> OBSResponse:
        """Update filter settings."""
        return await self.send_request("SetSourceFilterSettings", {
            "sourceName": source_name,
            "filterName": filter_name,
            "filterSettings": filter_settings,
            "overlay": overlay
        })

    async def remove_source_filter(self, source_name: str, filter_name: str) -> OBSResponse:
        """Remove a filter from a source."""
        return await self.send_request("RemoveSourceFilter", {
            "sourceName": source_name,
            "filterName": filter_name
        })

    # Recording Control

    async def get_record_status(self) -> OBSResponse:
        """Get current recording status."""
        return await self.send_request("GetRecordStatus")

    async def start_record(self) -> OBSResponse:
        """Start recording."""
        return await self.send_request("StartRecord")

    async def stop_record(self) -> OBSResponse:
        """Stop recording."""
        return await self.send_request("StopRecord")

    async def toggle_record(self) -> OBSResponse:
        """Toggle recording state."""
        return await self.send_request("ToggleRecord")

    async def set_record_directory(self, directory: str) -> OBSResponse:
        """Set the recording output directory."""
        return await self.send_request("SetRecordDirectory", {"recordDirectory": directory})

    # Utility Methods

    async def get_version(self) -> OBSResponse:
        """Get OBS version information."""
        return await self.send_request("GetVersion")

    async def is_recording(self) -> bool:
        """Check if OBS is currently recording."""
        response = await self.get_record_status()
        if response.success:
            return response.data.get("outputActive", False)
        return False


# Synchronous wrapper for non-async code
class OBSWebSocketSync:
    """
    Synchronous wrapper for OBSWebSocket.
    Runs async methods in an event loop.
    """

    def __init__(self, url: str = OBS_WEBSOCKET_URL):
        self._async_client = OBSWebSocket(url)
        self._loop: Optional[asyncio.AbstractEventLoop] = None

    def _get_loop(self) -> asyncio.AbstractEventLoop:
        if self._loop is None or self._loop.is_closed():
            try:
                self._loop = asyncio.get_running_loop()
            except RuntimeError:
                self._loop = asyncio.new_event_loop()
                asyncio.set_event_loop(self._loop)
        return self._loop

    def _run(self, coro):
        loop = self._get_loop()
        if loop.is_running():
            # If we're already in an async context, run in thread-safe manner
            # Note: This may have unexpected behavior if called from the wrong context
            log_debug("[WS] Running coroutine in existing event loop context")
            future = asyncio.run_coroutine_threadsafe(coro, loop)
            return future.result(timeout=30)
        else:
            return loop.run_until_complete(coro)

    @property
    def connected(self) -> bool:
        return self._async_client.connected

    def add_event_callback(self, event_type: str, callback: Callable[["OBSEvent"], None]):
        """Register a callback for a specific event type."""
        self._async_client.add_event_callback(event_type, callback)

    def add_global_event_callback(self, callback: Callable[["OBSEvent"], None]):
        """Register a callback for all events."""
        self._async_client.add_global_event_callback(callback)

    def remove_event_callback(self, event_type: str, callback: Callable[["OBSEvent"], None]):
        """Remove an event callback."""
        self._async_client.remove_event_callback(event_type, callback)

    def connect(self, max_retries: int = 30, retry_delay: float = 1.0) -> bool:
        return self._run(self._async_client.connect(max_retries, retry_delay))

    def disconnect(self):
        self._run(self._async_client.disconnect())

    def send_request(self, request_type: str, request_data: Optional[Dict] = None) -> OBSResponse:
        return self._run(self._async_client.send_request(request_type, request_data))

    # Profile Management
    def get_profile_list(self) -> OBSResponse:
        return self._run(self._async_client.get_profile_list())

    def get_current_profile(self) -> Optional[str]:
        return self._run(self._async_client.get_current_profile())

    def set_current_profile(self, profile_name: str) -> OBSResponse:
        return self._run(self._async_client.set_current_profile(profile_name))

    def create_profile(self, profile_name: str) -> OBSResponse:
        return self._run(self._async_client.create_profile(profile_name))

    # Scene Management
    def get_scene_list(self) -> OBSResponse:
        return self._run(self._async_client.get_scene_list())

    def get_current_program_scene(self) -> Optional[str]:
        return self._run(self._async_client.get_current_program_scene())

    def set_current_program_scene(self, scene_name: str) -> OBSResponse:
        return self._run(self._async_client.set_current_program_scene(scene_name))

    def create_scene(self, scene_name: str) -> OBSResponse:
        return self._run(self._async_client.create_scene(scene_name))

    def get_scene_item_list(self, scene_name: str) -> OBSResponse:
        return self._run(self._async_client.get_scene_item_list(scene_name))

    def remove_scene_item(self, scene_name: str, scene_item_id: int) -> OBSResponse:
        return self._run(self._async_client.remove_scene_item(scene_name, scene_item_id))

    # Input/Source Management
    def get_input_list(self, input_kind: Optional[str] = None) -> OBSResponse:
        return self._run(self._async_client.get_input_list(input_kind))

    def get_input_kind_list(self) -> OBSResponse:
        return self._run(self._async_client.get_input_kind_list())

    def create_input(self, scene_name: str, input_name: str, input_kind: str,
                     input_settings: Optional[Dict] = None, scene_item_enabled: bool = True) -> OBSResponse:
        return self._run(self._async_client.create_input(
            scene_name, input_name, input_kind, input_settings, scene_item_enabled))

    def get_input_settings(self, input_name: str) -> OBSResponse:
        return self._run(self._async_client.get_input_settings(input_name))

    def set_input_settings(self, input_name: str, input_settings: Dict, overlay: bool = True) -> OBSResponse:
        return self._run(self._async_client.set_input_settings(input_name, input_settings, overlay))

    # Filter Management
    def get_source_filter_list(self, source_name: str) -> OBSResponse:
        return self._run(self._async_client.get_source_filter_list(source_name))

    def create_source_filter(self, source_name: str, filter_name: str, filter_kind: str,
                             filter_settings: Optional[Dict] = None) -> OBSResponse:
        return self._run(self._async_client.create_source_filter(
            source_name, filter_name, filter_kind, filter_settings))

    def set_source_filter_settings(self, source_name: str, filter_name: str,
                                   filter_settings: Dict, overlay: bool = True) -> OBSResponse:
        return self._run(self._async_client.set_source_filter_settings(
            source_name, filter_name, filter_settings, overlay))

    def remove_source_filter(self, source_name: str, filter_name: str) -> OBSResponse:
        return self._run(self._async_client.remove_source_filter(source_name, filter_name))

    # Recording Control
    def get_record_status(self) -> OBSResponse:
        return self._run(self._async_client.get_record_status())

    def start_record(self) -> OBSResponse:
        return self._run(self._async_client.start_record())

    def stop_record(self) -> OBSResponse:
        return self._run(self._async_client.stop_record())

    def toggle_record(self) -> OBSResponse:
        return self._run(self._async_client.toggle_record())

    def set_record_directory(self, directory: str) -> OBSResponse:
        return self._run(self._async_client.set_record_directory(directory))

    # Utility
    def get_version(self) -> OBSResponse:
        return self._run(self._async_client.get_version())

    def is_recording(self) -> bool:
        return self._run(self._async_client.is_recording())
