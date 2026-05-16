import random
import ssl
import urllib.parse
import urllib.request
import json
from datetime import date, timedelta

# macOS Python 常見的 SSL 憑證問題，seeding 腳本允許 bypass
_SSL_CTX = ssl.create_default_context()
_SSL_CTX.check_hostname = False
_SSL_CTX.verify_mode = ssl.CERT_NONE

FIRESTORE_BASE = "https://firestore.googleapis.com/v1/projects/dragon-jump-f2b22/databases/(default)/documents"
API_KEY = "AIzaSyDfMRL--8qTzpKIxbfdbJL0Ifzg8NYP1II"

PLAYERS = [
    "SkyRider", "DragonHunter", "CloudSurfer", "StarJumper", "ThunderBolt",
    "IronFist", "NightOwl", "SwiftWind", "CrimsonEdge", "SilverWolf",
    "DarkPhoenix", "GoldenEagle", "ShadowBlade", "FrostByte", "BlazingFox",
    "StormRider", "MoonWalker", "SunChaser", "VoidWalker", "LightningBolt",
    "CrystalWing", "IceBreaker", "FireStorm", "AquaBlast", "EarthShaker",
    "NeonDragon", "CosmicRay", "PixelKnight", "SteelHawk", "WildTiger",
    "RunningBear", "FlyingFish", "SonicBoom", "TurboBlast", "RocketMan",
    "HyperDrive", "SpeedDemon", "QuickSilver", "RapidFire", "SwiftArrow",
    "BoldKnight", "BraveSoul", "DarkMatter", "DeepSpace", "StarDust",
    "MoonBeam", "SunFlare", "CosmicDust", "NebulaStar", "GalaxyWing",
    "QuantumLeap", "TimeBender", "SpaceRider", "OmegaForce", "AlphaWolf",
    "BetaRay", "GammaBlast", "DeltaStrike", "EpsilonRun", "ZetaWave",
    "ThetaFlow", "IotaBlaze", "KappaRush", "LambdaSurge", "MuForce",
    "NuSpeed", "XiDrive", "OmicronRace", "PiJump", "RhoFlight",
    "SigmaDash", "TauRun", "UpsilonSprint", "PhiBoost", "ChiClimb",
    "PsiLaunch", "OmegaRun", "ApexPred", "ZenMaster", "NinjaRun",
    "SamuraiX", "KungFuPanda", "DragonFly", "PhoenixRise", "TigerClaw",
    "PantherRun", "WolfPack", "BearForce", "EagleEye", "HawkEye",
    "FalconPunch", "SnakeEye", "LionHeart", "PantherClaw", "CheetahRun",
    "LeopardSprint", "JaguarLeap", "CougarPounce", "BlazeRunner", "NovaStar",
]

COUNTRIES = ["TW", "JP", "US", "KR", "HK", "SG", "MY", "TH", "VN", "PH",
             "ID", "AU", "GB", "FR", "DE", "BR", "CA", "MX", "IN", "CN"]

START_DATE = date(2026, 1, 1)
END_DATE = date(2026, 5, 16)
DATE_RANGE = (END_DATE - START_DATE).days


def random_score() -> int:
    if random.random() < 0.70:
        return random.randint(100, 800)
    return random.randint(800, 3000)


def random_date() -> str:
    return (START_DATE + timedelta(days=random.randint(0, DATE_RANGE))).isoformat()


def patch_player(name: str, score: int, country: str, date_str: str) -> int:
    encoded = urllib.parse.quote(name, safe="")
    url = (
        f"{FIRESTORE_BASE}/leaderboard/{encoded}"
        f"?key={API_KEY}"
        "&updateMask.fieldPaths=name"
        "&updateMask.fieldPaths=score"
        "&updateMask.fieldPaths=country"
        "&updateMask.fieldPaths=date"
    )
    body = json.dumps({
        "fields": {
            "name":    {"stringValue": name},
            "score":   {"integerValue": str(score)},
            "country": {"stringValue": country},
            "date":    {"stringValue": date_str},
        }
    }).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="PATCH")
    req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, context=_SSL_CTX) as resp:
        return resp.status


def main() -> None:
    players = PLAYERS[:100]
    ok = 0
    fail = 0
    for name in players:
        score = random_score()
        country = random.choice(COUNTRIES)
        date_str = random_date()
        try:
            status = patch_player(name, score, country, date_str)
            print(f"[OK {status}] {name:20s}  score={score:4d}  {country}  {date_str}")
            ok += 1
        except Exception as e:
            print(f"[ERR] {name}: {e}")
            fail += 1
    print(f"\nDone: {ok} succeeded, {fail} failed.")


if __name__ == "__main__":
    main()
