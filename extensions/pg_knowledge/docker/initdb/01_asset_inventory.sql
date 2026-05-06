CREATE TABLE IF NOT EXISTS asset_inventory (
    ip TEXT PRIMARY KEY,
    asset_name TEXT NOT NULL,
    asset_env TEXT NOT NULL,
    asset_owner TEXT NOT NULL
);

INSERT INTO asset_inventory (ip, asset_name, asset_env, asset_owner) VALUES
    ('222.133.52.20', 'edge-gateway-01', 'prod', 'secops'),
    ('10.10.10.8', 'internal-api-01', 'staging', 'platform')
ON CONFLICT (ip) DO UPDATE
SET asset_name = EXCLUDED.asset_name,
    asset_env = EXCLUDED.asset_env,
    asset_owner = EXCLUDED.asset_owner;
