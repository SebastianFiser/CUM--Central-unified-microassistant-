from dataclasses import dataclass
from typing import Any, Dict, Optional


@dataclass
class Message:
	id: str
	sender_id: str
	type: str
	payload: Dict[str, Any]


@dataclass
class Command(Message):
	action: str


@dataclass
class Event(Message):
	event: str


def command_to_dict(command_id: str, action: str, payload: Dict[str, Any], sender_id: str) -> Dict[str, Any]:
	return {
		"id": command_id,
		"sender_id": sender_id,
		"type": "command",
		"action": action,
		"payload": payload,
	}


def event_to_dict(event_id: str, event_name: str, payload: Dict[str, Any], sender_id: str) -> Dict[str, Any]:
	return {
		"id": event_id,
		"sender_id": sender_id,
		"type": "event",
		"event": event_name,
		"payload": payload,
	}


def get_message_id(message: Dict[str, Any]) -> Optional[str]:
	return message.get("id")

def status_response_to_dict(event_id: str, device_id: str, status: str, last_seen: float, sender_id: str) -> Dict[str, Any]:
	return {
		"id": event_id,
		"sender_id": sender_id,
        "type": "event",
		"event": "status_response",
		"payload": {
			"device_id": device_id,
            "status": status,
            "last_seen": last_seen,
        }
    }