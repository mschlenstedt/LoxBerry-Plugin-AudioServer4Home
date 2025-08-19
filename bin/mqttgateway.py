"""Example script to test the MusicAssistant client."""

from __future__ import annotations

import json
from dataclasses import dataclass, asdict
import argparse
import asyncio
import logging
from pprint import pprint
import time

from music_assistant_client import MusicAssistantClient
from music_assistant_models.enums import EventType

# Get parsed passed in arguments.
parser = argparse.ArgumentParser(description="MusicAssistant Client Example.")
parser.add_argument(
    "url",
    type=str,
    help="URL of MASS server, e.g. http://localhost:8095",
)
parser.add_argument(
    "--log-level",
    type=str,
    default="info",
    help="Provide logging level. Example --log-level debug, default=info, "
    "possible=(critical, error, warning, info, debug)",
)

args = parser.parse_args()

# Connect to MusicAssistent
async def client_listen(
    mass: MusicAssistantClient,
    init_ready: asyncio.Event) -> None:
    await mass.start_listening(init_ready=init_ready) 

# Set default for JSON conversation
def set_default_json(obj):
    if isinstance(obj, set):
        return list(obj)
    raise TypeError

# register listener for new players
async def handle_player_added(event: MassEvent) -> None:
    """Handle Mass Player Added event."""
    print ("Hallo")

if __name__ == "__main__":
    # configure logging
    logging.basicConfig(level=args.log_level.upper())

    async def run_mass() -> None:
        """Run the MusicAssistant client."""
        # run the client
        async with MusicAssistantClient(args.url, None) as client:
            init_ready = asyncio.Event()
            listen_task = asyncio.create_task(
                client_listen(client, init_ready)
            )
            await init_ready.wait()
            logging.info(len(client.players.players))
            playersdict = dict()
            for player in client.players.players:
                logging.info("Found player: %s", player.name)
                playersdict[player.player_id] = asdict(player)
            #playersdict[player.player_id] = json.dumps(asdict(player), default=set_default)
            print( json.dumps(playersdict, default=set_default_json) )
                #for attr, value in player.__dict__.items():
                #    playersd[attr] = value
            client.subscribe(handle_player_added, EventType.PLAYER_UPDATED)
            while (1):
                print ("Tick")
                time.sleep(5)

    # run the client
    asyncio.run(run_mass())
