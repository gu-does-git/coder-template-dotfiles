import { s3 } from "bun";
import { spawnSync } from "child_process";

const result = spawnSync("beads", ["ready", "--json"], {
  cwd: "/mnt/projects/newSnUtils",
  encoding: "utf-8",
});

if (result.error) {
  console.error("Failed to run beads:", result.error.message);
  process.exit(1);
}

const stdout = result.stdout?.trim();
if (!stdout || result.status !== 0) {
  console.error("beads ready failed:", result.stderr);
  process.exit(1);
}

// Validate JSON before uploading to avoid corrupt data in S3
JSON.parse(stdout);

const file = s3.file("beads/latest.json");
await file.write(stdout, { type: "application/json" });
console.log("Uploaded beads healthcheck to s3://lobe/beads/latest.json");
