(async () => {
  const { env, pipeline } = await import("@xenova/transformers");
  const cacheDir = process.env.XENOVA_CACHE_DIR || "/opt/agentmemory/model-cache";

  env.cacheDir = cacheDir;
  env.allowLocalModels = true;
  env.allowRemoteModels = true;

  const extractor = await pipeline("feature-extraction", "Xenova/all-MiniLM-L6-v2");
  await extractor(["agentmemory model cache warmup"], {
    pooling: "mean",
    normalize: true,
  });

  console.log(`Cached Xenova/all-MiniLM-L6-v2 in ${cacheDir}`);
})();
