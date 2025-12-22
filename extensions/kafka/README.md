# wp-connectors/Testcase 使用说明

本目录提供一套基于 Kafka 的端到端校验用例，验证统一 Kafka Source/Sink 连接器是否按预期工作。

- 发送端：`wpgen` 将样例数据写入 Kafka（输入 topic，默认 `wp.testcase.events.raw`）
- 引擎端：`wparse` 读取 Kafka 输入，解析并路由到多个 Sink（其中包含 Kafka 输出 topic，默认 `wp.testcase.events.parsed`，以及一个文件型 Sink）
- 可选校验：使用 `wpkit kafka consume` 验证 Kafka 输出 topic 的消息

## 数据流图

下图展示 testcase 的数据流与关键环节（环境变量 `KAFKA_INPUT_TOPIC/KAFKA_OUTPUT_TOPIC` 可覆写 topic 名称，默认 `wp.testcase.events.raw/wp.testcase.events.parsed`）。

```mermaid
flowchart LR
    subgraph Producer
      WPGEN[wpgen sample]\n(按 wpgen.toml 写 Kafka)
    end
    subgraph Kafka
      KAFKA_IN[(KAFKA_INPUT_TOPIC)]
      KAFKA_OUT[(KAFKA_OUTPUT_TOPIC)]
    end
    subgraph Engine
      WPARSE[wparse batch\n(-n 限制条数自动退出)]
      SINKS{{Sink Group\n(models/sink)}}
      OML[OML 映射/脱敏]
    end
    subgraph Verifier
      FILE[file sink: events.parsed.prototext]
      CONSUME[wpkit kafka consume\n(可选验证)]
    end

    WPGEN -- produce --> KAFKA_IN
    WPARSE -- consume --> KAFKA_IN
    WPARSE -- route --> OML --> SINKS
    SINKS -- write --> FILE
    SINKS -- produce --> KAFKA_OUT
    CONSUME -- verify --> KAFKA_OUT
```

如渲染不支持 Mermaid，可参考 ASCII 版：

```
wpgen(sample) --> Kafka(KAFKA_INPUT_TOPIC) --> wparse(batch) --> [OML/route] --> sinks{file,kafka}
    sinks --> file: data/out_dat/events.parsed.prototext
    sinks --> Kafka(KAFKA_OUTPUT_TOPIC) --> (optional) wpkit kafka consume 验证
```


## 目录结构

- `conf/`
  - `wparse.toml`：引擎主配置（目录/并发/日志等）
  - `wpgen.toml`：数据生成器配置（已指向 Kafka sink，并覆写输入 topic）
- `models/source/wpsrc.toml`：Source 路由（包含两个 `[[sources]]`：`kafka_input` 订阅输入 topic；`kafka_output_tap` 订阅输出 topic，用于自测/演示，可按需关闭）
- `models/sink/business.d/example.toml`：业务 Sink 路由（包含一个文件型 sink 与一个 Kafka sink）
- `models/oml/...`：OML 模型（结果字段映射/脱敏）
- `case_verify.sh`：一键校验脚本（启动 `wparse` → `wpgen` 发送 → 校验）

说明：Source 与 Sink 连接器 id 引用仓库根目录 `connectors/` 下的定义：
- `connectors/source.d/30-kafka.toml`：id=`kafka_src`（允许覆写 `topic/group_id/config`）
- `connectors/sink.d/30-kafka.toml`：id=`kafka_sink`（允许覆写 `topic/config/num_partitions/replication/brokers/fmt`）

## 前置要求

- 本机已启动 Kafka，默认地址 `localhost:9092`（或通过环境变量覆盖，见下文）
- 构建工具链可用（`cargo` 等）

## 快速开始

进入用例目录并运行脚本（默认 `debug`）：

```bash
cd extensions/wp-connectors/testcase
./case_verify.sh            # 或 ./case_verify.sh release
```

脚本主要步骤：
1) 清理运行目录（保留 `conf/` 模板）并构建二进制到 `target/<profile>`，加入 `PATH`
2) `wpkit conf check` 进行配置自检；清理数据目录
3) 后台启动 `wparse`（`-n` 限制处理条数，完成后自动退出）
4) 执行 `wpgen sample` 生成样例数据并写入 Kafka 输入 topic
5) 等待 `wparse` 退出并进行文件型 sink 校验（可选）

## 运行参数

脚本支持以下可选环境变量：

- `PROFILE`：构建与运行的 profile（`debug|release`），默认 `debug`
- `LINE_CNT`：生成/处理的样例条数，默认 `3000`
- `STAT_SEC`：统计打印间隔（秒），默认 `3`
- `KAFKA_BOOTSTRAP_SERVERS`：Kafka 地址，默认 `localhost:9092`
- `KAFKA_INPUT_TOPIC`：输入 topic（`wpgen` 写入、`wparse` 消费），默认 `wp.testcase.events.raw`
- `KAFKA_OUTPUT_TOPIC`：输出 topic（`wparse` 的 Kafka sink 写入），默认 `wp.testcase.events.parsed`

示例：

```bash
KAFKA_BOOTSTRAP_SERVERS=127.0.0.1:9092 KAFKA_INPUT_TOPIC=my_in KAFKA_OUTPUT_TOPIC=my_out ./case_verify.sh
```

## 结果验证

- 文件型 Sink：脚本会执行 `wpkit stat file` 与 `wpkit validate sink-file -v`，在 `data/out_dat/` 下可见 `events.parsed.prototext`（按 `models/sink/business.d/example.toml` 的文件型 sink 配置）
- Kafka 输出：可选执行以下命令查看输出 topic（建议使用全新 group，以免被其他消费者读走）

```bash
wpkit kafka consume --brokers ${KAFKA_BOOTSTRAP_SERVERS:-localhost:9092} \
  --group wpkit-consume-$$ \
  --topic "${KAFKA_OUTPUT_TOPIC:-wp.testcase.events.parsed}"
```

## 输出格式（Kafka Sink）

Kafka Sink 支持多种输出格式，默认 `json`。可在以下位置设置：
- 全局连接器：`connectors/sink.d/30-kafka.toml` 中设置 `fmt = "json|csv|kv|raw|show|proto-text"`（并允许覆写 `fmt`）
- 按路由覆写：在 `[[sink_group.sinks]].params` 中增加 `fmt = "..."`

说明：
- `proto` 需启用企业插件（当前默认退化为 `proto-text`）；
- 其它格式均以内置生成器输出一行（带换行）。

## 重要提示与排查

- 启动顺序：脚本已保证“先启动 `wparse` 再 `wpgen` 发送”，无需设置 `auto.offset.reset=earliest`；如需消费历史，亦可在 `models/source/wpsrc.toml` 的 `params_override.config` 中添加 `"auto.offset.reset=earliest"`
- 主题创建：连接器会尝试创建 topic，如集群禁用自动建主题或副本策略不符，请预先创建或调整 `num_partitions/replication`
- 认证安全：如需 SASL/SSL，请在 `connectors/sink.d/30-kafka.toml` 或路由 `params_override` 中通过 `config = ["security.protocol=...", ...]` 传入
- 输出被“吃掉”：用例自带 `kafka_output_tap` Source 订阅了 `wp.testcase.events.parsed`，可能在你消费时已被读取。验证时请使用一个全新的 `--group`

## 参考命令

- 查看解析到的路由：

```bash
wpkit sinks route -w .
wpkit sources route -w .
```

- 单独探活 Kafka：

```bash
wpkit kafka produce --brokers ${KAFKA_BOOTSTRAP_SERVERS:-localhost:9092} --topic test_topic
wpkit kafka consume --brokers ${KAFKA_BOOTSTRAP_SERVERS:-localhost:9092} --group wpkit-consume-$$ --topic test_topic
```

---
如需将输出格式切换为 `csv/kv/raw/show/proto-text` 并随脚本验证，建议直接在 `connectors/sink.d/30-kafka.toml` 中设置 `fmt`，或在 `models/sink/business.d/example.toml` 中的 Kafka sink 路由 `params` 下覆写 `fmt`。
