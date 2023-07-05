const { AutotaskClient } = require("@openzeppelin/defender-autotask-client");

async function uploadCode(autotaskId, apiKey, apiSecret) {
  const client = new AutotaskClient({ apiKey, apiSecret });
  await client.updateCodeFromFolder(autotaskId, "./build/relay");
}

async function main() {
  require("dotenv").config();
  const {
    RELAYER_API_KEY: apiKey,
    RELAYER_SECRET_KEY: apiSecret,
    AUTOTASK_ID: autotaskId,
  } = process.env;
  if (!autotaskId) throw new Error(`Missing autotask id`);
  await uploadCode(autotaskId, apiKey, apiSecret);
  console.log(`Code updated`);
}

if (require.main === module) {
  main().catch((error) => {
    throw new Error(error);
  });
}
