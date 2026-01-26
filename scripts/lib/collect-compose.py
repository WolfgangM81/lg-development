#!/usr/bin/env python3
"""
collect-compose.py - Compose Collector for LG-Development

Scans repos/*/docker-compose.yml, normalizes via `docker compose config --format json`,
merges all services, fixes paths, and generates a single docker-compose.yml in the project root.

Usage:
    python3 scripts/lib/collect-compose.py

Output:
    docker-compose.yml (in project root)
"""

import json
import os
import subprocess
import sys
from collections import OrderedDict
from pathlib import Path

# ============================================================
# Configuration
# ============================================================

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
REPOS_DIR = ROOT_DIR / "repos"
OUTPUT_FILE = ROOT_DIR / "docker-compose.yml"

# Layer ordering
LAYER_0_REPOS = ["lg-traefik", "lg-postgres", "lg-redis", "lg-dynamodb", "lg-verdaccio"]
LAYER_2_REPOS = ["lg-admin", "lg-management"]

# Service name ordering within layers
LAYER_0_SERVICE_ORDER = ["traefik", "postgres", "redis", "dynamodb", "verdaccio"]
LAYER_2_SERVICE_ORDER = ["admin", "management"]

# Known environment variables that should keep ${VAR} references
ENV_VAR_TEMPLATES = {
    "NODE_ENV": "${NODE_ENV:-development}",
    "DATABASE_URL": "${DATABASE_URL}",
    "REDIS_URL": "${REDIS_URL}",
    "JWT_SECRET": "${JWT_SECRET}",
    "INTERNAL_API_KEY": "${INTERNAL_API_KEY}",
    "MASTER_ENCRYPTION_KEY": "${MASTER_ENCRYPTION_KEY}",
    "POSTGRES_USER": "${POSTGRES_USER:-licenseguard}",
    "POSTGRES_PASSWORD": "${POSTGRES_PASSWORD:-changeme}",
    "POSTGRES_DB": "${POSTGRES_DB:-licenseguard}",
}

# Port variable templates: (service_name, container_port) -> env_var_template
PORT_VAR_TEMPLATES = {
    ("traefik", 80): "${TRAEFIK_HTTP_PORT:-80}",
    ("traefik", 443): "${TRAEFIK_HTTPS_PORT:-443}",
    ("traefik", 8080): "${TRAEFIK_DASHBOARD_PORT:-8080}",
    ("postgres", 5432): "${POSTGRES_PORT:-5432}",
    ("redis", 6379): "${REDIS_PORT:-6379}",
    ("verdaccio", 4873): "${VERDACCIO_PORT:-4873}",
    ("dynamodb", 8000): "${DYNAMODB_PORT:-8000}",
}

# Command overrides to preserve variable references
COMMAND_OVERRIDES = {
    "redis": "redis-server --requirepass ${REDIS_PASSWORD:-changeme}",
}

# Healthcheck overrides to preserve variable references
HEALTHCHECK_OVERRIDES = {
    "redis": {
        "test": ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:-changeme}", "ping"],
        "interval": "10s",
        "timeout": "5s",
        "retries": 5,
    },
    "postgres": {
        "test": ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-licenseguard}"],
        "interval": "10s",
        "timeout": "5s",
        "retries": 5,
    },
}

# Default env vars for docker compose config resolution
DEFAULT_ENV = {
    "POSTGRES_USER": "licenseguard",
    "POSTGRES_PASSWORD": "changeme",
    "POSTGRES_DB": "licenseguard",
    "REDIS_PASSWORD": "changeme",
    "JWT_SECRET": "dev-secret-key-minimum-32-characters-placeholder",
    "INTERNAL_API_KEY": "internal-dev-key",
    "MASTER_ENCRYPTION_KEY": "dev-encryption-key-placeholder",
    "NODE_ENV": "development",
    "TRAEFIK_HTTP_PORT": "80",
    "TRAEFIK_HTTPS_PORT": "443",
    "TRAEFIK_DASHBOARD_PORT": "8080",
    "POSTGRES_PORT": "5432",
    "REDIS_PORT": "6379",
    "VERDACCIO_PORT": "4873",
    "DYNAMODB_PORT": "8000",
    "DATABASE_URL": "postgres://licenseguard:changeme@postgres:5432/licenseguard",
    "REDIS_URL": "redis://:changeme@redis:6379",
}


# ============================================================
# Output helpers
# ============================================================

def info(msg):
    print(f"  {msg}")


def success(msg):
    print(f"  \033[32m{msg}\033[0m")


def warning(msg):
    print(f"  \033[33mWARNING: {msg}\033[0m", file=sys.stderr)


def error(msg):
    print(f"  \033[31mERROR: {msg}\033[0m", file=sys.stderr)


# ============================================================
# Repo discovery
# ============================================================

def find_repos_with_compose():
    """Find all repos that have a docker-compose.yml."""
    if not REPOS_DIR.exists():
        error(f"repos/ directory not found at {REPOS_DIR}")
        sys.exit(1)

    repos = OrderedDict()
    for d in sorted(REPOS_DIR.iterdir()):
        if d.is_dir() and (d / "docker-compose.yml").exists():
            repos[d.name] = d

    if not repos:
        error("No docker-compose.yml files found in repos/")
        sys.exit(1)

    return repos


def get_defined_services(repo_dir):
    """Get service names defined in a compose file (simple text parsing)."""
    compose_file = repo_dir / "docker-compose.yml"
    services = []
    in_services = False

    for line in compose_file.read_text().splitlines():
        stripped = line.strip()
        if stripped == "services:" or stripped == "services: ":
            in_services = True
            continue
        if in_services:
            if line.startswith("  ") and not line.startswith("    ") and ":" in stripped:
                name = stripped.split(":")[0].strip()
                if name and not name.startswith("#"):
                    services.append(name)
            elif not line.startswith(" ") and stripped and stripped != "services:":
                in_services = False

    return services


# ============================================================
# Docker compose config
# ============================================================

def build_env_for_subprocess():
    """Build environment dict for subprocess calls."""
    env = os.environ.copy()
    env.update(DEFAULT_ENV)
    # Override with .env if it exists
    env_file = ROOT_DIR / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            stripped = line.strip()
            if stripped and not stripped.startswith("#") and "=" in stripped:
                key, val = stripped.split("=", 1)
                env[key.strip()] = val.strip()
    return env


def create_stub_file(repo_dir, defined_services):
    """Create a temporary stub YAML file for missing depends_on references."""
    all_possible = {
        "postgres", "redis", "traefik",
        "user-service", "permissions-service", "api-keys-service",
        "menu-service", "tour-service", "secrets-service",
        "admin", "verdaccio", "dynamodb",
    }

    needed = all_possible - set(defined_services)
    if not needed:
        return None

    lines = ["services:"]
    for name in sorted(needed):
        lines.append(f"  {name}:")
        lines.append(f"    image: alpine:latest")
        lines.append(f"    healthcheck:")
        lines.append(f'      test: ["CMD", "echo", "ok"]')
        lines.append(f"      interval: 5s")
        lines.append(f"      timeout: 3s")
        lines.append(f"      retries: 3")

    stub_path = repo_dir / ".compose-stubs.yml"
    stub_path.write_text("\n".join(lines) + "\n")
    return stub_path


def get_compose_config(repo_dir, defined_services):
    """Run docker compose config --format json and return parsed JSON."""
    stub_path = create_stub_file(repo_dir, defined_services)

    cmd = ["docker", "compose", "-f", "docker-compose.yml"]
    if stub_path:
        cmd.extend(["-f", str(stub_path.name)])
    cmd.extend(["config", "--format", "json"])

    env = build_env_for_subprocess()

    try:
        result = subprocess.run(
            cmd,
            cwd=str(repo_dir),
            capture_output=True,
            text=True,
            env=env,
            timeout=30,
        )
    finally:
        if stub_path and stub_path.exists():
            stub_path.unlink()

    if result.returncode != 0:
        warning(f"docker compose config failed for {repo_dir.name}")
        if result.stderr:
            for line in result.stderr.strip().splitlines()[:5]:
                warning(f"  {line}")
        return None

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        warning(f"JSON parse error for {repo_dir.name}: {e}")
        return None


# ============================================================
# Path and value transformations
# ============================================================

def fix_path(abs_path):
    """Convert absolute path to relative path from ROOT_DIR."""
    if not os.path.isabs(abs_path):
        return abs_path
    try:
        rel = os.path.relpath(abs_path, str(ROOT_DIR))
        if rel.startswith(".."):
            return abs_path
        return "./" + rel
    except ValueError:
        return abs_path


def volume_to_short(vol_entry):
    """Convert a volume entry (dict from JSON) to short-form string."""
    if isinstance(vol_entry, str):
        return vol_entry

    vtype = vol_entry.get("type", "volume")
    source = vol_entry.get("source", "")
    target = vol_entry.get("target", "")
    read_only = vol_entry.get("read_only", False)

    if vtype == "bind":
        source = fix_path(source)

    parts = [source, target]
    if read_only:
        parts.append("ro")
    return ":".join(parts)


def port_to_short(port_entry, service_name):
    """Convert a port entry (dict from JSON) to short-form string with variable refs."""
    if isinstance(port_entry, str):
        return port_entry

    target = int(port_entry.get("target", 0))
    published = port_entry.get("published", "")

    key = (service_name, target)
    if key in PORT_VAR_TEMPLATES:
        return f"{PORT_VAR_TEMPLATES[key]}:{target}"

    if published:
        return f"{published}:{target}"
    return str(target)


def restore_env_vars(env_dict):
    """Replace resolved env values with variable references where known."""
    if not env_dict:
        return OrderedDict()

    result = OrderedDict()
    for key in sorted(env_dict.keys()):
        if key in ENV_VAR_TEMPLATES:
            result[key] = ENV_VAR_TEMPLATES[key]
        else:
            result[key] = env_dict[key]
    return result


# ============================================================
# Service processing
# ============================================================

def process_service(service_name, svc_config, repo_name):
    """Process a single service config from JSON into our internal format."""
    result = OrderedDict()

    # container_name
    if "container_name" in svc_config:
        result["container_name"] = svc_config["container_name"]

    # image
    if "image" in svc_config and "build" not in svc_config:
        result["image"] = svc_config["image"]

    # build
    if "build" in svc_config:
        build = svc_config["build"]
        if isinstance(build, dict):
            ctx = build.get("context", "")
            dockerfile = build.get("dockerfile", "Dockerfile")
            result["build"] = OrderedDict()
            result["build"]["context"] = fix_path(ctx)
            result["build"]["dockerfile"] = dockerfile
            if "args" in build and build["args"]:
                result["build"]["args"] = build["args"]
        else:
            result["build"] = fix_path(str(build))

    # user
    if "user" in svc_config:
        result["user"] = svc_config["user"]

    # command (skip null/empty)
    if service_name in COMMAND_OVERRIDES:
        result["command"] = COMMAND_OVERRIDES[service_name]
    elif "command" in svc_config and svc_config["command"] is not None:
        cmd = svc_config["command"]
        if isinstance(cmd, list):
            result["command"] = cmd
        else:
            result["command"] = cmd

    # ports
    if "ports" in svc_config and svc_config["ports"]:
        result["ports"] = [port_to_short(p, service_name) for p in svc_config["ports"]]

    # environment
    if "environment" in svc_config and svc_config["environment"]:
        result["environment"] = restore_env_vars(svc_config["environment"])

    # volumes
    if "volumes" in svc_config and svc_config["volumes"]:
        result["volumes"] = [volume_to_short(v) for v in svc_config["volumes"]]

    # depends_on (exclude stub services)
    if "depends_on" in svc_config and svc_config["depends_on"]:
        deps = OrderedDict()
        for dep_name, dep_config in sorted(svc_config["depends_on"].items()):
            if isinstance(dep_config, dict):
                condition = dep_config.get("condition", "service_started")
                # Only keep condition, drop other defaults
                deps[dep_name] = {"condition": condition}
            else:
                deps[dep_name] = {"condition": "service_started"}
        result["depends_on"] = deps

    # networks
    if "networks" in svc_config:
        nets = svc_config["networks"]
        if isinstance(nets, dict):
            # Filter to only lg-* networks
            net_list = [n for n in nets.keys() if n.startswith("lg-") or n == "default"]
            if net_list:
                result["networks"] = net_list
        elif isinstance(nets, list):
            result["networks"] = [n for n in nets if n.startswith("lg-") or n == "default"]

    # labels
    if "labels" in svc_config and svc_config["labels"]:
        labels = svc_config["labels"]
        if isinstance(labels, dict):
            result["labels"] = OrderedDict(sorted(labels.items()))
        elif isinstance(labels, list):
            label_dict = OrderedDict()
            for item in sorted(labels):
                if "=" in item:
                    k, v = item.split("=", 1)
                    label_dict[k] = v
            result["labels"] = label_dict

    # healthcheck (use override if available to preserve variable refs)
    if service_name in HEALTHCHECK_OVERRIDES:
        result["healthcheck"] = OrderedDict(HEALTHCHECK_OVERRIDES[service_name])
    elif "healthcheck" in svc_config and svc_config["healthcheck"]:
        hc = svc_config["healthcheck"]
        result["healthcheck"] = OrderedDict()
        if "test" in hc:
            result["healthcheck"]["test"] = hc["test"]
        for field in ("interval", "timeout", "retries", "start_period"):
            if field in hc:
                result["healthcheck"][field] = hc[field]

    # restart
    if "restart" in svc_config and svc_config["restart"] != "no":
        result["restart"] = svc_config["restart"]

    return result


def handle_secrets_service(svc_config):
    """Special handling for lg-secrets-service:
    - Use shared postgres/redis instead of own
    - Switch networks to lg-internal/lg-public
    - Add traefik labels
    """
    # Fix networks
    svc_config["networks"] = ["lg-internal", "lg-public"]

    # Fix depends_on: add redis and traefik
    if "depends_on" not in svc_config:
        svc_config["depends_on"] = OrderedDict()
    deps = svc_config["depends_on"]
    deps["postgres"] = {"condition": "service_healthy"}
    deps["redis"] = {"condition": "service_healthy"}
    deps["traefik"] = {"condition": "service_started"}
    # Re-sort
    svc_config["depends_on"] = OrderedDict(sorted(deps.items()))

    # Fix environment
    if "environment" in svc_config:
        env = svc_config["environment"]
        env["DATABASE_URL"] = "${DATABASE_URL}"
        env["REDIS_URL"] = "${REDIS_URL}"
        env["JWT_SECRET"] = "${JWT_SECRET}"
        env["MASTER_ENCRYPTION_KEY"] = "${MASTER_ENCRYPTION_KEY}"
        env["NODE_ENV"] = "${NODE_ENV:-development}"
        if "PORT" not in env:
            env["PORT"] = "3007"
        # Re-sort
        svc_config["environment"] = OrderedDict(sorted(env.items()))

    # Add traefik labels if missing
    if "labels" not in svc_config:
        svc_config["labels"] = OrderedDict()
    labels = svc_config["labels"]
    if not any("traefik" in str(k) for k in labels):
        labels["traefik.enable"] = "true"
        labels["traefik.http.routers.secrets-service.entrypoints"] = "http"
        labels["traefik.http.routers.secrets-service.rule"] = "PathPrefix(`/api/secrets`)"
        labels["traefik.http.services.secrets-service.loadbalancer.server.port"] = "3007"
        svc_config["labels"] = OrderedDict(sorted(labels.items()))

    return svc_config


# ============================================================
# YAML generation
# ============================================================

def yaml_quote(val):
    """Quote a YAML scalar value if needed."""
    if val is None:
        return "null"

    s = str(val)
    if not s:
        return '""'

    # Check if quoting is needed
    needs_quote = False
    lower = s.lower()
    if lower in ("true", "false", "yes", "no", "null", "~", "on", "off"):
        needs_quote = True
    elif s.startswith(("*", "&", "!", "{", "[", ">", "|", "@", "`", "'", '"', "%")):
        needs_quote = True
    elif ":" in s or "#" in s:
        needs_quote = True
    elif s.startswith("- ") or s.startswith("? "):
        needs_quote = True

    # Check if it looks like a number
    try:
        float(s)
        needs_quote = True
    except ValueError:
        pass

    if needs_quote:
        escaped = s.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    return s


def gen_service_yaml(name, config):
    """Generate YAML lines for a single service definition."""
    lines = []
    ind = "    "  # 4 spaces for service properties

    lines.append(f"  {name}:")

    for key, val in config.items():
        if key == "container_name":
            lines.append(f"{ind}container_name: {val}")

        elif key == "image":
            lines.append(f"{ind}image: {val}")

        elif key == "build":
            if isinstance(val, str):
                lines.append(f"{ind}build: {val}")
            else:
                lines.append(f"{ind}build:")
                for bk, bv in val.items():
                    if isinstance(bv, dict):
                        lines.append(f"{ind}  {bk}:")
                        for ak, av in bv.items():
                            lines.append(f"{ind}    {ak}: {yaml_quote(av)}")
                    else:
                        lines.append(f"{ind}  {bk}: {bv}")

        elif key == "user":
            lines.append(f'{ind}user: "{val}"')

        elif key == "command":
            if isinstance(val, list):
                lines.append(f"{ind}command: {json.dumps(val)}")
            elif "${" in str(val):
                lines.append(f"{ind}command: {val}")
            else:
                lines.append(f"{ind}command: {yaml_quote(val)}")

        elif key == "ports":
            lines.append(f"{ind}ports:")
            for p in val:
                lines.append(f'{ind}  - "{p}"')

        elif key == "environment":
            lines.append(f"{ind}environment:")
            if isinstance(val, dict):
                for ek, ev in val.items():
                    ev_str = str(ev) if ev is not None else ""
                    if "${" in ev_str:
                        lines.append(f"{ind}  {ek}: {ev_str}")
                    else:
                        lines.append(f"{ind}  {ek}: {yaml_quote(ev_str)}")
            elif isinstance(val, list):
                for item in val:
                    lines.append(f"{ind}  - {item}")

        elif key == "volumes":
            lines.append(f"{ind}volumes:")
            for v in val:
                lines.append(f"{ind}  - {v}")

        elif key == "depends_on":
            lines.append(f"{ind}depends_on:")
            for dep_name, dep_config in val.items():
                if isinstance(dep_config, dict):
                    cond = dep_config.get("condition", "service_started")
                    lines.append(f"{ind}  {dep_name}:")
                    lines.append(f"{ind}    condition: {cond}")
                else:
                    lines.append(f"{ind}  {dep_name}:")
                    lines.append(f"{ind}    condition: service_started")

        elif key == "networks":
            lines.append(f"{ind}networks:")
            for n in val:
                lines.append(f"{ind}  - {n}")

        elif key == "labels":
            lines.append(f"{ind}labels:")
            if isinstance(val, dict):
                for lk, lv in val.items():
                    lines.append(f'{ind}  - "{lk}={lv}"')
            elif isinstance(val, list):
                for label in val:
                    lines.append(f'{ind}  - "{label}"')

        elif key == "healthcheck":
            lines.append(f"{ind}healthcheck:")
            for hk, hv in val.items():
                if hk == "test":
                    if isinstance(hv, list):
                        lines.append(f"{ind}  test: {json.dumps(hv)}")
                    else:
                        lines.append(f'{ind}  test: {yaml_quote(hv)}')
                elif hk == "retries":
                    lines.append(f"{ind}  {hk}: {hv}")
                else:
                    lines.append(f"{ind}  {hk}: {yaml_quote(str(hv)) if isinstance(hv, str) else hv}")

        elif key == "restart":
            lines.append(f"{ind}restart: {val}")

    return "\n".join(lines)


def generate_compose_yaml(all_services, all_volumes, layer_0, layer_1, layer_2):
    """Generate the complete docker-compose.yml content."""
    lines = []

    # Header
    lines.append("# Auto-generated by collect-compose.py")
    lines.append("# Do NOT edit manually - run 'make prepare' to regenerate")
    lines.append("")

    # Networks
    lines.append("networks:")
    lines.append("  lg-public:")
    lines.append("    name: lg-public")
    lines.append("    driver: bridge")
    lines.append("  lg-internal:")
    lines.append("    name: lg-internal")
    lines.append("    driver: bridge")
    lines.append("")

    # Volumes
    if all_volumes:
        lines.append("volumes:")
        for vol_name in sorted(all_volumes):
            lines.append(f"  {vol_name}:")
        lines.append("")

    # Services
    lines.append("services:")

    # Layer 0: Infrastructure
    if layer_0:
        lines.append("  # === Layer 0: Infrastructure ===")
        for svc_name in layer_0:
            if svc_name in all_services:
                lines.append(gen_service_yaml(svc_name, all_services[svc_name]))
                lines.append("")

    # Layer 1: Backend Services
    if layer_1:
        lines.append("  # === Layer 1: Backend Services ===")
        for svc_name in layer_1:
            if svc_name in all_services:
                lines.append(gen_service_yaml(svc_name, all_services[svc_name]))
                lines.append("")

    # Layer 2: Frontend
    if layer_2:
        lines.append("  # === Layer 2: Frontend ===")
        for svc_name in layer_2:
            if svc_name in all_services:
                lines.append(gen_service_yaml(svc_name, all_services[svc_name]))
                lines.append("")

    return "\n".join(lines)


# ============================================================
# Main
# ============================================================

def collect():
    """Main collector logic."""
    print("Collecting compose configurations...")
    print("")

    repos = find_repos_with_compose()
    info(f"Found {len(repos)} repos with docker-compose.yml")
    print("")

    all_services = OrderedDict()
    all_volumes = set()
    layer_0_names = []
    layer_1_names = []
    layer_2_names = []

    for repo_name, repo_dir in repos.items():
        defined_services = get_defined_services(repo_dir)
        if not defined_services:
            continue

        info(f"Processing {repo_name}...")

        config = get_compose_config(repo_dir, defined_services)
        if not config:
            warning(f"Skipping {repo_name} (config failed)")
            continue

        services = config.get("services", {})

        for svc_name in defined_services:
            if svc_name not in services:
                warning(f"  Service '{svc_name}' not found in config output for {repo_name}")
                continue

            # Special case: skip secrets-service's own postgres
            if repo_name == "lg-secrets-service" and svc_name == "postgres":
                info(f"  Skipping {svc_name} from {repo_name} (using shared postgres)")
                continue

            svc_config = services[svc_name]
            processed = process_service(svc_name, svc_config, repo_name)

            # Special case: secrets-service adjustments
            if repo_name == "lg-secrets-service" and svc_name == "secrets-service":
                processed = handle_secrets_service(processed)

            all_services[svc_name] = processed

            # Categorize into layers
            if repo_name in LAYER_0_REPOS:
                layer_0_names.append(svc_name)
            elif repo_name in LAYER_2_REPOS:
                layer_2_names.append(svc_name)
            elif repo_name.endswith("-service"):
                layer_1_names.append(svc_name)
            else:
                # Unknown category, treat as layer 1
                layer_1_names.append(svc_name)

        # Collect named volumes (skip secrets-service's own postgres_data conflict)
        volumes = config.get("volumes", {})
        for vol_name in volumes:
            all_volumes.add(vol_name)

    # Order layers
    layer_0_ordered = [s for s in LAYER_0_SERVICE_ORDER if s in layer_0_names]
    layer_1_ordered = sorted(layer_1_names)
    layer_2_ordered = [s for s in LAYER_2_SERVICE_ORDER if s in layer_2_names]

    # Generate output
    output = generate_compose_yaml(
        all_services, all_volumes,
        layer_0_ordered, layer_1_ordered, layer_2_ordered
    )

    # Write file
    OUTPUT_FILE.write_text(output)

    print("")
    success(f"Generated {OUTPUT_FILE.relative_to(ROOT_DIR)}")
    info(f"  Services: {len(all_services)}")
    info(f"  Volumes:  {len(all_volumes)}")
    info(f"  Layers:   {len(layer_0_ordered)} infra + {len(layer_1_ordered)} backend + {len(layer_2_ordered)} frontend")
    print("")
    info("Validate with: docker compose config")
    print("")


if __name__ == "__main__":
    collect()
