const cache = new Map();
const DEFAULT_TTL = 60 * 1000; // 1 phút

exports.getCached = (key) => {
  const item = cache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiry) {
    cache.delete(key);
    return null;
  }
  return item.value;
};

exports.setCache = (key, value, ttlMs = DEFAULT_TTL) => {
  cache.set(key, { value, expiry: Date.now() + ttlMs });
};

exports.clearCache = (keyPrefix) => {
  for (const key of cache.keys()) {
    if (key.startsWith(keyPrefix)) cache.delete(key);
  }
};
