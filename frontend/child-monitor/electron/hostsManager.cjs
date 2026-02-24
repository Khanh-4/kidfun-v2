const fs = require('fs');
const { exec } = require('child_process');
const path = require('path');

const HOSTS_PATH = path.join('C:', 'Windows', 'System32', 'drivers', 'etc', 'hosts');
const MARKER_START = '# KidFun-Block-Start';
const MARKER_END = '# KidFun-Block-End';

function readHostsFile() {
  try {
    return fs.readFileSync(HOSTS_PATH, 'utf8');
  } catch (err) {
    console.error('Failed to read hosts file:', err.message);
    return null;
  }
}

function writeHostsFile(content) {
  try {
    fs.writeFileSync(HOSTS_PATH, content, 'utf8');
    return true;
  } catch (err) {
    console.error('Failed to write hosts file:', err.message);
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
  exec('ipconfig /flushdns', (err) => {
    if (err) {
      console.error('Failed to flush DNS:', err.message);
    }
  });
}

function updateBlockedSites(sites) {
  if (!Array.isArray(sites)) return false;

  const content = readHostsFile();
  if (content === null) return false;

  let cleaned = removeKidFunBlock(content);

  if (sites.length > 0) {
    const blockEntries = sites
      .map((site) => {
        const domain = site.replace(/^(https?:\/\/)?(www\.)?/, '').replace(/\/.*$/, '');
        return `127.0.0.1 ${domain}\n127.0.0.1 www.${domain}`;
      })
      .join('\n');

    cleaned = cleaned.trimEnd() + '\n\n' + MARKER_START + '\n' + blockEntries + '\n' + MARKER_END;
  }

  const success = writeHostsFile(cleaned);
  if (success) {
    flushDns();
  }
  return success;
}

function removeAllBlocks() {
  const content = readHostsFile();
  if (content === null) return false;

  const cleaned = removeKidFunBlock(content);
  const success = writeHostsFile(cleaned);
  if (success) {
    flushDns();
  }
  return success;
}

module.exports = {
  updateBlockedSites,
  removeAllBlocks,
};
