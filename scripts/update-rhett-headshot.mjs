import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { basename } from 'node:path';

const targetOrg = 'my-org';
const rhettUserId = '005Qi00000b75IbIAI';
const imagePath = 'C:\\Users\\ChristopherLowman\\Downloads\\Image (1).jpg';
const apiVersion = '67.0';

function runSf(args) {
  const command = `& 'C:\\Program Files\\sf\\bin\\sf.cmd' ${args.map((arg) => `'${String(arg).replace(/'/g, "''")}'`).join(' ')}`;
  return JSON.parse(execFileSync('powershell.exe', ['-NoProfile', '-Command', command], {
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 10
  }));
}

async function sfFetch(instanceUrl, accessToken, path, options = {}) {
  const response = await fetch(`${instanceUrl}/services/data/v${apiVersion}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      ...(options.headers ?? {})
    }
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${options.method ?? 'GET'} ${path} failed: ${response.status} ${text}`);
  }
  return body;
}

const org = runSf(['org', 'display', '--target-org', targetOrg, '--json']).result;
const instanceUrl = org.instanceUrl;
const accessToken = org.accessToken;

if (!instanceUrl || !accessToken) {
  throw new Error('Could not read Salesforce instance URL/access token from sf org display.');
}

const imageBase64 = readFileSync(imagePath).toString('base64');
const title = 'Rhett Delaney Headshot 2026';
const pathOnClient = basename(imagePath);

const contentVersionResult = await sfFetch(instanceUrl, accessToken, '/sobjects/ContentVersion', {
  method: 'POST',
  body: JSON.stringify({
    Title: title,
    PathOnClient: pathOnClient,
    VersionData: imageBase64
  })
});

const contentVersion = await sfFetch(
  instanceUrl,
  accessToken,
  `/query?q=${encodeURIComponent(`SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = '${contentVersionResult.id}'`)}`
);
const versionRecord = contentVersion.records?.[0];
if (!versionRecord?.ContentDocumentId) {
  throw new Error(`Could not find ContentDocumentId for uploaded ContentVersion ${contentVersionResult.id}`);
}

const distributionResult = await sfFetch(instanceUrl, accessToken, '/sobjects/ContentDistribution', {
  method: 'POST',
  body: JSON.stringify({
    Name: title,
    ContentVersionId: contentVersionResult.id,
    PreferencesAllowViewInBrowser: true,
    PreferencesAllowOriginalDownload: true,
    PreferencesNotifyOnVisit: false
  })
});

const distributionQuery = await sfFetch(
  instanceUrl,
  accessToken,
  `/query?q=${encodeURIComponent(`SELECT Id, ContentDownloadUrl, DistributionPublicUrl FROM ContentDistribution WHERE Id = '${distributionResult.id}'`)}`
);
const distribution = distributionQuery.records?.[0];
const headshotUrl = distribution?.ContentDownloadUrl || distribution?.DistributionPublicUrl;
if (!headshotUrl) {
  throw new Error(`Could not read public download URL from ContentDistribution ${distributionResult.id}`);
}

await sfFetch(instanceUrl, accessToken, `/sobjects/User/${rhettUserId}`, {
  method: 'PATCH',
  body: JSON.stringify({
    Headshot_URL__c: headshotUrl
  })
});

console.log(JSON.stringify({
  uploadedContentVersionId: contentVersionResult.id,
  contentDocumentId: versionRecord.ContentDocumentId,
  contentDistributionId: distributionResult.id,
  rhettUserId,
  headshotUrl
}, null, 2));
