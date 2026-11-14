// Clash Verge Rev 扩展脚本示例。组名是 AI-EXIT。
//
// 停：占位符还在、或没有任何 enabled:true 的服务时，main() 会抛错，避免把半成品载入运行时。
// 抛错信息里故意不包含服务器、用户名和密码。
// 凭据只留在本机，不要提交，不要贴到聊天。
//
// MODE = "subscription"  默认。只用订阅里已有的节点，不需要固定出口账号。
// MODE = "fixed-exit"    可选进阶。同一出口走多条路径，需要你自己的 ISP 代理账号。
//
// 很多订阅用 proxy-providers，脚本执行时 config.proxies 还是空的，
// 所以这里不检查节点名是否已经出现在 config.proxies 里。
// 名字必须和客户端里显示的完全一致。订阅更新后名字变了，要回来改。

const MODE = "subscription";
const AI_EXIT = "AI-EXIT";

// 至少两个，且必须改掉 REPLACE_ME。
const SUB_NODES = ["REPLACE_ME_NODE_1", "REPLACE_ME_NODE_2"];

// 仅 fixed-exit 读取。subscription 模式下这些占位符可以留着。
const ISP = {
  server: "REPLACE_ME_ISP_HOST",
  port: 0,
  username: "REPLACE_ME_ISP_USER",
  password: "REPLACE_ME_ISP_PASSWORD",
};
const HOPS = ["REPLACE_ME_HOP_1", "REPLACE_ME_HOP_2"];

// enabled 仍是 false 的条目不会写入规则。示例里的域名只说明写法。
// 改成你实际使用、且在你所在地区官方支持的服务，再把 enabled 设为 true。不用的删掉。
const AI_SERVICES = [
  {
    enabled: false,
    name: "example-claude",
    process: "(?i)^Claude(?: Helper.*)?$",
    suffixes: ["claude.ai", "anthropic.com", "claude.com", "claudeusercontent.com"],
    domains: [],
    keywords: [],
  },
];

// 需要直连的单位域名。没有就保持空数组。
const COMPANY_DOMAINS = [];

// 仅当 COMPANY_DOMAINS 非空时写入 nameserver-policy。
// 换成你的网络里该用的解析地址，不要假设所有人都在同一个国家。
// 可选示例：1.1.1.1、8.8.8.8、223.5.5.5，或单位内网 DNS。
const COMPANY_DNS = ["REPLACE_ME_DNS"];

function isPlaceholder(value) {
  return typeof value !== "string" || value.indexOf("REPLACE_ME") !== -1 || value.indexOf("<") !== -1;
}

function assertReady() {
  var problems = [];
  if (MODE !== "subscription" && MODE !== "fixed-exit") {
    problems.push("MODE 只能是 subscription 或 fixed-exit");
  }
  if (MODE === "subscription") {
    if (!SUB_NODES.length) problems.push("SUB_NODES 为空");
    if (SUB_NODES.some(function (name) { return isPlaceholder(name); })) {
      problems.push("SUB_NODES 仍有占位符");
    }
  }
  if (MODE === "fixed-exit") {
    if (typeof ISP.port !== "number" || ISP.port <= 0 || ISP.port > 65535) {
      problems.push("ISP.port 必须是 1 到 65535 的数字，0 会被拒绝");
    }
    ["server", "username", "password"].forEach(function (key) {
      if (isPlaceholder(String(ISP[key] || ""))) problems.push("ISP." + key + " 仍是占位符");
    });
    if (!HOPS.length) problems.push("HOPS 为空");
    if (HOPS.some(function (name) { return isPlaceholder(name); })) {
      problems.push("HOPS 仍有占位符");
    }
  }
  var enabled = AI_SERVICES.filter(function (svc) { return svc && svc.enabled; });
  if (!enabled.length) problems.push("AI_SERVICES 里没有 enabled:true 的条目");
  enabled.forEach(function (svc) {
    var n = (svc.suffixes || []).length + (svc.domains || []).length + (svc.keywords || []).length;
    if (!svc.process && n === 0) problems.push("有服务没有任何匹配条件");
  });
  if (COMPANY_DOMAINS.length) {
    if (COMPANY_DOMAINS.some(function (item) { return isPlaceholder(item); })) {
      problems.push("COMPANY_DOMAINS 含占位符");
    }
    if (!COMPANY_DNS.length || COMPANY_DNS.some(function (item) { return isPlaceholder(item); })) {
      problems.push("写了单位域名，但 COMPANY_DNS 仍是占位符");
    }
  }
  if (problems.length) {
    throw new Error("已拒绝加载：" + problems.join("；") + "。请先改占位符。此错误不包含服务器、用户名或密码。");
  }
}

function main(config) {
  assertReady();
  config.proxies = config.proxies || [];
  config["proxy-groups"] = config["proxy-groups"] || [];
  config.rules = config.rules || [];

  var members;
  if (MODE === "fixed-exit") {
    members = [];
    HOPS.forEach(function (hop, i) {
      var name = "ISP-via" + (i + 1);
      config.proxies.push({
        name: name,
        type: "socks5",
        server: ISP.server,
        port: ISP.port,
        username: ISP.username,
        password: ISP.password,
        udp: false,
        "dialer-proxy": hop,
      });
      members.push(name);
    });
    config.proxies.push({
      name: "ISP-direct",
      type: "socks5",
      server: ISP.server,
      port: ISP.port,
      username: ISP.username,
      password: ISP.password,
      udp: false,
    });
    members.push("ISP-direct");
  } else {
    members = SUB_NODES.slice();
  }

  // 若内核报未知字段 expected-status，删掉这一项即可。
  config["proxy-groups"].unshift({
    name: AI_EXIT,
    type: "fallback",
    proxies: members,
    url: "http://www.gstatic.com/generate_204",
    interval: 300,
    "expected-status": 204,
  });

  var rules = [];
  AI_SERVICES.forEach(function (svc) {
    if (!svc.enabled) return;
    if (svc.process) rules.push("PROCESS-NAME-REGEX," + svc.process + "," + AI_EXIT);
    (svc.suffixes || []).forEach(function (item) { rules.push("DOMAIN-SUFFIX," + item + "," + AI_EXIT); });
    (svc.domains || []).forEach(function (item) { rules.push("DOMAIN," + item + "," + AI_EXIT); });
    (svc.keywords || []).forEach(function (item) { rules.push("DOMAIN-KEYWORD," + item + "," + AI_EXIT); });
  });
  COMPANY_DOMAINS.forEach(function (item) { rules.push("DOMAIN-SUFFIX," + item + ",DIRECT"); });
  config.rules = rules.concat(config.rules);

  if (COMPANY_DOMAINS.length) {
    config.dns = config.dns || {};
    var policy = config.dns["nameserver-policy"] || {};
    COMPANY_DOMAINS.forEach(function (item) { policy["+." + item] = COMPANY_DNS.slice(); });
    config.dns["nameserver-policy"] = policy;
  }
  return config;
}
