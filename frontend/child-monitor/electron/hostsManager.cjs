const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

const HOSTS_PATH = path.join('C:', 'Windows', 'System32', 'drivers', 'etc', 'hosts');
const MARKER_START = '# KidFun-Block-Start';
const MARKER_END = '# KidFun-Block-End';

function readHostsFile() {
  try {
    const content = fs.readFileSync(HOSTS_PATH, 'utf8');
    console.log('[HostsManager] Read hosts file successfully, length:', content.length);
    return content;
  } catch (err) {
    if (err.code === 'EPERM' || err.code === 'EACCES') {
      console.error('[HostsManager] PERMISSION DENIED: Cần chạy app với quyền Administrator để sửa hosts file');
    } else {
      console.error('[HostsManager] Failed to read hosts file:', err.message);
    }
    return null;
  }
}

function writeHostsFile(content) {
  try {
    fs.writeFileSync(HOSTS_PATH, content, 'utf8');
    console.log('[HostsManager] Wrote hosts file successfully');
    return true;
  } catch (err) {
    if (err.code === 'EPERM' || err.code === 'EACCES') {
      console.error('[HostsManager] PERMISSION DENIED: Cần chạy app với quyền Administrator để ghi hosts file');
      console.error('[HostsManager] Hướng dẫn: Click chuột phải vào app → Run as Administrator');
    } else {
      console.error('[HostsManager] Failed to write hosts file:', err.message);
    }
    return false;
  }
}

function removeKidFunBlock(content) {
  const startIdx = content.indexOf(MARKER_START);
  const endIdx = content.indexOf(MARKER_END);

  if (startIdx === -1 || endIdx === -1) {
    return content;
  }

  const before = content.substring(0, startIdx).trimEnd();
  const after = content.substring(endIdx + MARKER_END.length).trimStart();

  return before + (after ? '\n' + after : '');
}

function flushDns() {
  try {
    const result = execSync('ipconfig /flushdns', { encoding: 'utf8' });
    console.log('[HostsManager] Flush DNS result:', result.trim());
    return true;
  } catch (err) {
    console.error('[HostsManager] Failed to flush DNS:', err.message);
    return false;
  }
}

/**
 * Extract clean domain from URL/input
 * "https://www.facebook.com/page" → "facebook.com"
 */
function extractDomain(site) {
  return site
    .replace(/^(https?:\/\/)?(www\.)?/, '')
    .replace(/\/.*$/, '')
    .replace(/:\d+$/, '')
    .trim()
    .toLowerCase();
}

function updateBlockedSites(sites) {
  if (!Array.isArray(sites)) {
    console.error('[HostsManager] sites is not an array:', sites);
    return false;
  }

  console.log('[HostsManager] === Updating blocked sites ===');
  console.log('[HostsManager] Input sites:', sites);

  const content = readHostsFile();
  if (content === null) return false;

  console.log('[HostsManager] --- Hosts file BEFORE ---');
  // Only log KidFun section if present
  const existingStart = content.indexOf(MARKER_START);
  if (existingStart !== -1) {
    const existingEnd = content.indexOf(MARKER_END);
    console.log(content.substring(existingStart, existingEnd + MARKER_END.length));
  } else {
    console.log('[HostsManager] (no existing KidFun block)');
  }

  let cleaned = removeKidFunBlock(content);

  if (sites.length > 0) {
    const domains = [...new Set(sites.map(extractDomain).filter(Boolean))];
    console.log('[HostsManager] Domains to block:', domains);

    const blockEntries = domains
      .map((domain) => {
        return `127.0.0.1 ${domain} # KidFun Blocked\n127.0.0.1 www.${domain} # KidFun Blocked`;
      })
      .join('\n');

    cleaned = cleaned.trimEnd() + '\n\n' + MARKER_START + '\n' + blockEntries + '\n' + MARKER_END;
  } else {
    console.log('[HostsManager] No sites to block, cleaning hosts file');
  }

  console.log('[HostsManager] --- Hosts file AFTER (KidFun section) ---');
  const newStart = cleaned.indexOf(MARKER_START);
  if (newStart !== -1) {
    const newEnd = cleaned.indexOf(MARKER_END);
    console.log(cleaned.substring(newStart, newEnd + MARKER_END.length));
  } else {
    console.log('[HostsManager] (no KidFun block - all cleared)');
  }

  const success = writeHostsFile(cleaned);
  if (success) {
    flushDns();
    console.log('[HostsManager] === Blocked sites updated successfully ===');
  } else {
    console.error('[HostsManager] === FAILED to update blocked sites ===');
  }
  return success;
}

function removeAllBlocks() {
  console.log('[HostsManager] === Removing all KidFun blocks ===');
  const content = readHostsFile();
  if (content === null) return false;

  const cleaned = removeKidFunBlock(content);
  const success = writeHostsFile(cleaned);
  if (success) {
    flushDns();
    console.log('[HostsManager] === All blocks removed successfully ===');
  }
  return success;
}

module.exports = {
  updateBlockedSites,
  removeAllBlocks,
};
