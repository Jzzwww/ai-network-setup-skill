// Clash Verge Rev 扩展脚本（Script override）示例 —— 全部为占位符
// 用途：给指定 AI 工具一个固定出口（同一静态 ISP 代理经多个前置跳组成 Fallback），公司域名直连。
// 凭据只在本地填写，切勿提交到 git。修改后需在 UI 重新激活订阅（= 重载，先关闭 AI 客户端）。
const AI_TARGET = "AI-ISP";
const ISP = { server: "<ISP代理host>", port: 0 /* <端口> */, username: "<用户名>", password: "<密码>" };
const HOPS = ["<前置节点A名称>", "<前置节点B名称>"]; // 订阅中已有节点名
const COMPANY_DOMAINS = ["<公司域名1>", "<公司域名2>"];

function main(config) {
  config.proxies = config.proxies || [];
  const names = [];
  HOPS.forEach((hop, i) => {
    const name = `ISP-via${i + 1}`;
    config.proxies.push({ name, type: "socks5", ...ISP, udp: false, "dialer-proxy": hop });
    names.push(name);
  });
  config.proxies.push({ name: "ISP-direct", type: "socks5", ...ISP, udp: false });
  names.push("ISP-direct");

  config["proxy-groups"] = config["proxy-groups"] || [];
  config["proxy-groups"].unshift({
    name: AI_TARGET, type: "fallback", proxies: names,
    url: "http://www.gstatic.com/generate_204", interval: 300, "expected-status": 204,
  });

  const aiRules = [
    `PROCESS-NAME-REGEX,(?i)^Claude(?: Helper.*)?$,${AI_TARGET}`,
    ...["claude.ai", "anthropic.com", "claude.com", "claudeusercontent.com",
        "claudemcpclient.com", "claudemcpcontent.com"].map(d => `DOMAIN-SUFFIX,${d},${AI_TARGET}`),
    ...["servd-anthropic-website.b-cdn.net", "anthropic.com.cdn.cloudflare.net",
        "anthropic-com.ghost.io"].map(d => `DOMAIN,${d},${AI_TARGET}`),
    `DOMAIN-KEYWORD,anthropic,${AI_TARGET}`,
    `DOMAIN-KEYWORD,claude,${AI_TARGET}`,
    ...COMPANY_DOMAINS.map(d => `DOMAIN-SUFFIX,${d},DIRECT`),
  ];
  config.rules = [...aiRules, ...(config.rules || [])];

  config.dns = config.dns || {};
  config.dns["nameserver-policy"] = Object.assign(config.dns["nameserver-policy"] || {},
    Object.fromEntries(COMPANY_DOMAINS.map(d => [`+.${d}`, ["<公司内网DNS>", "223.5.5.5"]])));
  return config;
}
