const {chromium}=require('playwright');
const fs=require('fs');
(async()=>{
 const b=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',args:['--no-sandbox']});
 const p=await b.newPage();
 const src='data:image/png;base64,'+fs.readFileSync('P2-query-optimisation/evidence06-indexes-created.png').toString('base64');
 await p.setContent(`<img src="${src}">`);
 console.log(await p.locator('img').evaluate(x=>({complete:x.complete,w:x.naturalWidth,h:x.naturalHeight,src:x.src.slice(0,40)})));
 await b.close();
})();
