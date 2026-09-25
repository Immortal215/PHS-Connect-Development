"use strict";

const major = Number(process.versions.node.split(".")[0]);
if (major !== 22) {
  console.error(
    `PHS Connect Functions and Firebase predeploy require Node 22; found Node ${process.versions.node}. ` +
    "Switch to Node 22 before running npm run check or deploying Functions."
  );
  process.exit(1);
}
