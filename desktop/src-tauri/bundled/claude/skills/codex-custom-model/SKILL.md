---
name: codex-custom-model
description: 配置 CODEX 使用自定义大模型（如 DeepSeek、Ollama 等）。涵盖 config.toml 配置、代理搭建、Responses API 转换。关键词：CODEX、config.toml、自定义模型、自定义 API、DeepSeek、Ollama、model_provider、wire_api、Responses API、本地模型、代理转换。
---

# CODEX 自定义模型配置

## 概述

CODEX 桌面端和 CLI 支持通过 `config.toml` 配置自定义模型。**关键限制**：CODEX 新版本强制使用 OpenAI **Responses API**（`wire_api = "responses"`），大多数第三方 API（如 DeepSeek、Ollama）只支持 Chat Completions API，因此需要搭建中间代理做协议转换。

## 配置文件位置

| 类型 | 路径 |
|------|------|
| 全局配置 | `~/.codex/config.toml` |
| 项目配置 | `项目根目录/.codex/config.toml` |

**注意**：CODEX 桌面端可能在 UI 中有独立配置，会覆盖 config.toml 的设置。

## config.toml 结构

```toml
model_provider = "my-provider"    # provider 名称，对应下面的 [model_providers.xxx]
model = "gpt-5.5"                 # 模型名（桌面端 UI 可能限制选项）
model_reasoning_effort = "medium" # low / medium / high
disable_response_storage = true   # 禁用响应存储

[model_providers.my-provider]
name = "my-provider"
base_url = "http://localhost:3456/v1"  # API 地址
wire_api = "responses"                 # CODEX 新版本只支持 "responses"
requires_openai_auth = false           # 是否需要 OpenAI 格式的 Bearer token
# api_key = "sk-xxx"                   # API key（可选，也可用环境变量）
```

## 完整配置示例

### 1. 直接使用 OpenAI 兼容服务

如果服务商直接支持 Responses API（如 gaccode）：

```toml
model_provider = "gac"
model = "gpt-5.5"

[model_providers.gac]
name = "gac"
base_url = "https://gaccode.com/codex/v1"
wire_api = "responses"
```

### 2. 通过本地代理使用 DeepSeek

搭建代理将 Responses API 转为 Chat API：

**代理服务器 (`server.js`)**：

```javascript
const express = require('express');
const app = express();

const API_CONFIG = {
  baseUrl: 'https://api.deepseek.com/v1',
  apiKey: 'sk-your-key',
  model: 'deepseek-v4-flash',
};

app.use(express.json({ limit: '10mb' }));

app.get('/v1/models', (req, res) => {
  res.json({ object: 'list', data: [
    { id: 'deepseek-v4-flash', object: 'model' },
  ]});
});

app.post('/v1/responses', async (req, res) => {
  const { input, instructions, stream = false } = req.body;

  // 转换为 Chat API 格式
  const messages = [];
  if (instructions) messages.push({ role: 'system', content: instructions });
  messages.push({ role: 'user', content: extractText(input) });

  if (stream) {
    // Streaming 处理
    res.setHeader('Content-Type', 'text/event-stream');
    const apiRes = await fetch(`${API_CONFIG.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${API_CONFIG.apiKey}` },
      body: JSON.stringify({ model: API_CONFIG.model, messages, stream: true }),
    });

    const reader = apiRes.body.getReader();
    let buffer = '', responseId = `resp_${Date.now()}`;

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      // 解析 SSE 并转发为 Responses API 格式
      // ...
    }

    res.write(`data: ${JSON.stringify({ type: 'response.completed' })}\n\n`);
    res.end();
  } else {
    // 非 Streaming
    const apiRes = await fetch(`${API_CONFIG.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${API_CONFIG.apiKey}` },
      body: JSON.stringify({ model: API_CONFIG.model, messages }),
    });
    const data = await apiRes.json();
    res.json({
      id: `resp_${Date.now()}`,
      object: 'response',
      output: [{ type: 'message', role: 'assistant', content: [{ type: 'output_text', text: data.choices[0].message.content }] }],
    });
  }
});

function extractText(input) {
  if (!input) return '';
  if (typeof input === 'string') return input;
  if (Array.isArray(input)) return input.map(i => typeof i === 'string' ? i : i.text || '').join('\n');
  return String(input);
}

app.listen(3456, () => console.log('Proxy on :3456'));
```

**CODEX 配置**：
```toml
model_provider = "my-proxy"
model = "gpt-5.5"

[model_providers.my-proxy]
name = "my-proxy"
base_url = "http://localhost:3456/v1"
wire_api = "responses"
requires_openai_auth = false
```

## Responses API ↔ Chat API 转换

### CODEX 发送的请求格式

```
POST /v1/responses
{
  "model": "...",
  "input": "用户消息",          // 字符串或数组
  "instructions": "系统提示词",
  "stream": true/false,
  "tools": [...]               // 可选
}
```

### 期望的响应格式（非 streaming）

```json
{
  "id": "resp_xxx",
  "object": "response",
  "output": [{
    "type": "message",
    "role": "assistant",
    "content": [{ "type": "output_text", "text": "回复内容" }]
  }]
}
```

### 期望的响应格式（streaming）

```json
data: {"type":"response.output_text.delta","delta":"部分内容","item_id":"resp_xxx"}

data: {"type":"response.output_text.done","item_id":"resp_xxx"}

data: {"type":"response.completed","response":{...}}
```

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| `503 Service Unavailable` | API 地址不可达 | 检查 base_url 和 API key |
| `wire_api = "chat" is no longer supported` | CODEX 新版本废弃了 chat 协议 | 改用 `wire_api = "responses"` |
| 桌面端配置不生效 | 桌面端 UI 覆盖了 config.toml | 改用 CODEX CLI，或在 UI 中手动设置 |
| `stream disconnected before completion` | SSE 格式不对或连接中断 | 确保发送 `response.completed` 事件 |
