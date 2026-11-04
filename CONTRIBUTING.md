# 贡献指南 / Contributing

- **绝不提交**真实凭据、订阅 URL、个人/账号相关 IP、公司内部域名；一律使用 `<占位符>`。提交前自查：
  `grep -rnE '([0-9]{1,3}\.){3}[0-9]{1,3}|password|token|subscribe' .`
- 内容须符合定位：稳定出口、兼容公司网络、防泄漏。不接受规避地区限制、封禁、KYC 或伪造身份的内容。
- 新增层级文档遵循格式：目标 / 前置条件 / 步骤 / 验证 / 常见坑 / 回滚。
- 脚本须只读、通过 `shellcheck -S warning`。
- 价格、性能数据需附来源，否则标注"需自行核实"。
- PR 请说明测试环境（OS、客户端版本）。English contributions/translations welcome.
