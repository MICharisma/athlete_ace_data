import argparse
import concurrent.futures
import datetime
import hashlib
import json
from pathlib import Path
import urllib.error
import urllib.request

import yaml


ROOT = Path(__file__).resolve().parents[1]
ABBREVIATIONS = {"NY": "NYK", "NO": "NOP", "GS": "GSW", "SA": "SAS", "UTAH": "UTA", "WSH": "WAS", "BRK": "BKN", "CHO": "CHA", "PHO": "PHX"}


def capture(entry, media_root, as_of, existing):
    request = urllib.request.Request(entry["asset_url"], headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            content_type = response.headers.get_content_type()
            if not content_type.startswith("image/"):
                raise ValueError(f"Expected an image, received {content_type}")
            data = response.read(10 * 1024 * 1024 + 1)
            if not data or len(data) > 10 * 1024 * 1024:
                raise ValueError("Image is empty or exceeds 10 MiB")
        checksum = hashlib.sha256(data).hexdigest()
        entry.update(content_type=content_type, byte_size=len(data), sha256=checksum, captured_on=as_of)
        old = existing.get(entry["asset_url"])
        if old and old["attributes"]["sha256"] == checksum:
            entry.update(reuse_representation=old["code"], reuse_logo=old["references"]["subject"])
        else:
            path = media_root / entry["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.exists() and path.read_bytes() != data:
                raise ValueError(f"Existing capture differs: {path}")
            path.write_bytes(data)
        return entry, None
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        return None, {**entry, "error": str(error)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--as-of", required=True, type=datetime.date.fromisoformat)
    parser.add_argument("--media-root", required=True, type=Path)
    args = parser.parse_args()
    as_of = args.as_of.isoformat()
    nba = json.loads((ROOT / "sources/coverage_2026/nba.json").read_text())
    assert len(nba["teams"]) == 30, "Expected 30 captured NBA teams"
    pilot = yaml.safe_load((ROOT / "yaml/coverage_2026/visual_assets.yaml").read_text())
    existing = {row["source"]["asset_url"]: row for row in pilot["records"] if row["type"] == "AssetRepresentation" and "asset_url" in row["source"]}
    entries = []
    for team in nba["teams"]:
        abbreviation = ABBREVIATIONS.get(team["abbreviation"], team["abbreviation"])
        owner = f"BKT-NBA-TEAM-{abbreviation}"
        for logo in team["logos"]:
            role = "_".join(part for part in logo["rel"] if part != "full")
            entries.append({"kind": "logo", "owner_type": "Team", "owner": owner, "name": f"{team['name']} {role.replace('_', ' ')} logo",
                            "code": f"{owner}-LOGO-{role.upper()}", "role": role, "url": team["url"], "asset_url": logo["href"],
                            "path": f"nba/{as_of}/{owner}/{role}.png", "view": "default", "file_format": "png"})
    entries.append({"kind": "logo", "owner_type": "League", "owner": "BKT-LEAGUE-NBA", "name": "NBA league logo", "code": "BKT-LEAGUE-NBA-LOGO-PRIMARY",
                    "role": "primary", "url": "https://www.nba.com/", "asset_url": "https://cdn.nba.com/logos/leagues/logo-nba.svg",
                    "path": f"nba/{as_of}/BKT-LEAGUE-NBA/primary.svg", "view": "default", "file_format": "svg"})
    lebron = next(player for team in nba["teams"] for player in team["players"] if player["source_id"] == "1966")
    assert (lebron["first_name"], lebron["last_name"]) == ("LeBron", "James")
    for provider, page, url in [
        ("NBA", "https://www.nba.com/player/2544/lebron-james", "https://cdn.nba.com/headshots/nba/latest/1040x760/2544.png"),
        ("ESPN", "https://www.espn.com/nba/player/_/id/1966/lebron-james", lebron["photo_url"]),
    ]:
        entries.append({"kind": "portrait", "owner_type": "Figure", "owner": "FIGURE-BKT-NBA-PLAYER-JAMES_LEBRON", "name": f"LeBron James {provider} headshot",
                        "code": f"JAMES_LEBRON-PORTRAIT-{provider}-{as_of.replace('-', '_')}", "url": page, "asset_url": url,
                        "path": f"nba/{as_of}/JAMES_LEBRON/{provider.lower()}-headshot.png", "view": f"{provider.lower()}_headshot", "file_format": "png"})
    assert len(entries) == 483, "Expected 480 team marks, one league mark, and two headshots"
    available, unavailable = [], []
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        futures = [executor.submit(capture, entry, args.media_root, as_of, existing) for entry in entries]
        for index, future in enumerate(concurrent.futures.as_completed(futures), 1):
            entry, failure = future.result()
            (available if entry else unavailable).append(entry or failure)
            if index % 40 == 0:
                print(f"Captured {index}/{len(entries)} files; unavailable: {len(unavailable)}", flush=True)
    output = ROOT / "sources/nba_media_2026"
    output.mkdir(parents=True, exist_ok=True)
    document = {"captured_on": as_of, "repository": "MICharisma/athlete_ace_media", "listing": "sources/coverage_2026/nba.json",
                "meaning": "All listed NBA team logo variants, one official league mark, and two LeBron headshots. Image observation does not establish usage periods or historical jerseys.",
                "available": sorted(available, key=lambda entry: entry["code"]), "unavailable": sorted(unavailable, key=lambda entry: entry["code"])}
    (output / "capture.json").write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({"available": len(available), "unavailable": len(unavailable), "reused": sum("reuse_representation" in entry for entry in available)}), flush=True)


if __name__ == "__main__":
    main()
