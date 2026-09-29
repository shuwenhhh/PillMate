# MediStar 后端执行计划

本文档把 MediStar 的 AI Assistant 后端拆成可独立验收的 Batch。每个 Batch 建议对应一个 Git commit，完成后再进入下一批。

## 总体架构

```text
SwiftData
  ↓
iOS JSON 请求
  ↓
FastAPI：鉴权 / 校验 / 脱敏 / 限流
  ↓
确定性统计
  ↓
输入 Moderation
  ↓
OpenAI Responses API
  ↓
Structured JSON + 输出安全检查
  ↓
SwiftUI 结果卡片
```

目标是让 AI 只做健康记录摘要和中性追问，不做诊断、处方或治疗建议。

## Batch 0：产品范围和安全边界

**任务**

- 定义允许的功能：次数、日期、时间间隔、记录共现和用户填写内容的摘要。
- 明确禁止：诊断、药物增减、停药/换药、疗效判断和因果结论。
- 定义 `ok`、`needs_clarification`、`refusal`、`safety_escalation` 四种状态。
- 完成隐私政策、用户同意和数据删除规则草案。

**验收**：准备至少 20 个允许/禁止问题样例，并为每个样例定义预期状态。

## Batch 1：FastAPI 服务基础

**任务**

- 保持 `MediStarBackend` 为独立 Python 服务。
- 完成 FastAPI app、环境变量、CORS 和统一错误格式。
- 保留 `GET /health`。
- 提供本地启动命令和 `.env.example`。

**验收**：`curl http://localhost:8000/health` 返回 `{"status":"ok"}`。

## Batch 2：API 数据合同

**接口**：`POST /v1/assistant/analyze`

前端传递：

- 日期范围、时区、语言和问题类型。
- `MedicationRecordEntity` 的服药时间、感受、间隔、心率、血压和备注。
- `MedicineEntity` 的药名、剂量、时间窗口、频率和 active 状态。
- `HealthJournalEntryEntity` 的 Mood、Symptoms、血压、心率和记录时间。
- `consentVersion` 和一次性 `requestId`。

默认不传姓名、邮箱、地址、GPS、设备 ID 和完整 SwiftData 数据库。药名和剂量属于敏感健康数据，应在隐私政策中说明。

**验收**：Pydantic 能拒绝非法血压、心率、日期范围、超长备注和过大的记录数组。

## Batch 3：确定性统计层

**任务**

- 后端计算服药总次数、时间窗口内/外次数和记录间隔。
- 计算 Mood、Symptoms、血压和心率的记录数量及时间关系。
- 每条统计结果生成对应的 `evidenceId`。
- 禁止把计算任务交给模型猜测。

**验收**：固定输入每次返回相同统计结果，且所有 observation 都能追溯到输入记录。

## Batch 4：OpenAI 调用层

**任务**

- 使用 OpenAI 官方 Python SDK 和 Responses API。
- 使用 Pydantic Structured Outputs 固定返回 JSON。
- 使用环境变量读取模型名称。
- 显式设置 `store=False`，不使用长期 conversation state。
- API Key 只能存在后端环境变量，不能进入 iOS App。

**验收**：无 API Key 返回 503；配置 Key 后能返回合法的 `AssistantResponse`。

## Batch 5：安全和合规拦截

**任务**

- 请求发送前调用 Moderation。
- 模型返回后再次检查 Moderation。
- 校验所有 `evidenceId` 是否真实存在。
- 拦截诊断、改药、停药、换药和因果性表达。
- 危险描述只返回中性的本地急救/医疗机构提示，不做诊断。
- 强制追加固定 disclaimer。

**验收**：要求“我应该停药吗？”得到 `refusal`；危险描述得到 `safety_escalation`；普通记录问题得到摘要。

## Batch 6：SwiftUI 接入

**修改目标**

- `RecordsAssistantView.swift`
- `RecordsAnalysisService.swift`

**任务**

- 用 `URLSession` 调用 `/v1/assistant/analyze`。
- 增加 loading、空数据、错误和 retry 状态。
- 展示 summary、observations、follow-up questions 和 disclaimer。
- 网络失败时不影响本地 SwiftData 数据。

**验收**：点击预设问题后，页面能显示加载状态、结果或可恢复错误。

## Batch 7：登录和隐私控制

**任务**

- 验证 Sign in with Apple token。
- 每个用户只能访问自己的请求上下文。
- 加入每用户限流和每日调用次数限制。
- 日志只保留 request ID、耗时、状态码和错误类型，不记录健康备注或完整 prompt。
- 支持用户删除 AI 请求数据。

**验收**：未授权请求被拒绝；用户无法读取其他用户数据；日志中没有原始健康内容。

## Batch 8：测试和评估

**测试类型**

- API schema 和 SwiftData 转 JSON 测试。
- 空数据、超长数据、中文/英文、时区测试。
- 诊断、改药、停药、危险症状和 Prompt injection 测试。
- OpenAI 超时、429、5xx 和无效 JSON 测试。
- 输出 evidence ID 和 disclaimer 测试。

**验收**：所有响应都是合法 JSON；越界问题不会返回医疗建议；错误响应不泄露 API Key 或健康数据。

## Batch 9：部署和上线

**任务**

- 部署到 HTTPS 环境。
- 使用 Secret Manager 保存 API Key。
- 配置健康检查、超时、错误监控、费用告警和回滚。
- 只允许正式 iOS Bundle ID 或受信任客户端访问。
- 上线前完成隐私政策、用户同意和删除流程。

## 推荐提交顺序

```text
backend(batch-01): bootstrap FastAPI service
backend(batch-02): add assistant request schemas
backend(batch-03): add deterministic record summaries
backend(batch-04): add OpenAI Responses integration
backend(batch-05): add moderation and safety gates
ios(batch-06): connect Records Assistant to backend
backend(batch-07): add auth and rate limits
backend(batch-08): add safety evaluation tests
backend(batch-09): prepare production deployment
```

## MVP 范围

先完成 Batch 1–6，即可跑通：

```text
SwiftData 记录 → FastAPI → OpenAI 摘要 → SwiftUI 展示
```

Batch 7–9 是正式面向真实用户上线前必须完成的安全、隐私和生产准备。

## 官方参考

- [Create a model response](https://developers.openai.com/api/reference/cli/resources/responses/methods/create)
- [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
- [Moderations API](https://developers.openai.com/api/reference/resources/moderations)
- [Data controls](https://developers.openai.com/api/docs/guides/your-data)
