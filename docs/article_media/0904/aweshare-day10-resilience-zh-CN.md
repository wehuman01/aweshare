# codex等多家ai宕机，aweshare无事发生

![aweshare](../../logo/logo.png)

昨天晚上[OpenAI、Anthropic，多家AI公司正遭遇服务中断](https://mp.weixin.qq.com/s/vLR_gnrT0O0th93RsG1bmg)，Grok、Codex 等平台接连宕机，各处一片哀嚎。有朋友来问：你们那个共享 hub 挂了没？

答案有点无聊：没挂，连个故障通报都没得写。该跑的请求在跑，该记的账在记，唯一的变化是账本里几行数字——两条模型的错误率比平时高了一截。

不过这事值得记下来。上一篇讲去中心化的设计哲学，这一篇就是实测：aweshare 的社区 hub 跑满 10 天，还正好撞上一次上游大面积宕机。把账本摊开，看看「没事」是怎么来的。

## 先看 10 天的账本

一条命令的事：

```bash
aweshare hub usage
```

时间跨度 8 月 25 日至 9 月 4 日，汇总下来：

- **10 个厂商、20 个模型**，挂成 **32 条通道（alias）**——同一个模型，不同生产者可以各挂一条；厂商从 glm、gpt、deepseek，到 step、minimax、kimi、mimo、agnes、sensenova、seed，一共十家；
- **3,664 次请求，总成功率 93.4%**，共 93 条「生产者 × 消费者 × 模型」的流；
- **约 3.53 亿 token**（prompt 3.51 亿、completion 193 万）。

哪个模型最能打？账本排得清清楚楚（按请求量取前八）：

| 模型 | 请求 | 成功率 | token 合计 | 几家在供 |
|---|---|---|---|---|
| glm-5.3 | 1,036 | 96.3% | 1.22 亿 | 2 |
| glm-5.3-flash | 820 | 97.1% | 1.21 亿 | 1 |
| gpt-5.6-luna | 570 | 87.5% | 4,380 万 | 2 |
| gpt-5.6-terra | 297 | 86.2% | 2,960 万 | 2 |
| step-3.7-flash | 171 | 87.1% | 256 万 | 4 |
| minimax-m3 | 157 | 99.4% | 889 万 | 2 |
| deepseek-v4-pro | 123 | 98.4% | 778 万 | 1 |
| mimo-v2.5-pro | 90 | 98.9% | 419 万 | 1 |

冠军是 glm-5.3：1,036 次请求、1.22 亿 token；亚军 glm-5.3-flash：820 次、1.21 亿。两兄弟吃掉全网 69% 的流量——重度用户用脚投票，主力机型就是这么选出来的。三、四名是 gpt-5.6-luna 和 gpt-5.6-terra，也就是昨天被上游拖累的那两条。再往后，step、minimax、deepseek、mimo 各有各的稳定客源——一家模型出事，顶多伤一小块。



## 昨天发生了什么：账本里的「故障」

先说实话：不是零损伤。走同一条上游的 gpt-5.6-luna 和 gpt-5.6-terra，10 天错误率分别是 12.5% 和 13.8%，明显高于 glm 家族的 3% 上下；账本里还躺着几个 30 秒超时。这就是上游宕机在一个共享网络里的样子：**几行数字、一列错误率，而不是一个停摆的下午。**

但重点是：**没有一个人的工作停下来。** 因为：

- gpt-5.6-luna 和 gpt-5.6-terra 各有 **2 个独立生产者**（peng1 和 jiyu2，两台不同机器、各自的上游通道）。从昨天白天到今天上午，两家的 gpt-5.6 通道都有请求记录，最后使用时间分别是今天 10:32 和 10:38——一条抖，另一条接。
- 与事发上游无关的另外 18 个模型——glm、deepseek、kimi、minimax、step、mimo、sensenova、seed、agnes——照常营业。过去两天，93 条流里有 44 条活跃。
- 消费者要做的只有一件事：换个 alias，或者干脆换个模型，接着跑。

在单体平台上，上游宕机就是你的工作停摆；在这张网上，它只是账本里的一列数字。**故障没有消失，只是被摊薄了。**

## 有问题也没事：冗余是自己长出来的

有意思的是：冗余这件事，没人规划过。20 个模型里有 9 个天然有两个以上来源——step-3.7-flash 有 4 个生产者，step-router-v1 有 3 个，glm-5.3、kimi-k2.7-code、minimax-m3、gpt-5.6 两兄弟各有 2 个。

道理很朴素：共享经济的逻辑是「谁有什么就挂什么」。一个模型好用、用的人多，自然有第二个人把它挂上自家货架。**热门必然被重复，重复就是备份。** 这比任何「高可用架构」都便宜——因为它压根不是架构，是分布式的副产品。

再叠上一篇讲过的两条设计：

- **没有中心可打。** 上游 key 在生产者自己机器上，hub 只是个协调点；打掉任何一个环节，剩下的照常转。
- **退出成本接近零。** 消费者换条通道，改两行环境变量的事，随时用脚投票。

顺带说个反面例子，也当亮亮家底：5 个生产者里有一个10 天成功率只有 70%，但它没拖垮任何人——坏只坏在自家那排货架上，消费者的请求自然绕着走。**一个节点的弱，弱在它自己，不弱在全网。** 这也是aweshare 去中心设计的魅力。

## 一句话

**可用性不是从某一家买来的，是从很多来源长出来的。** 单点的可靠性有上限——再大的厂也会宕机，昨天刚刚证明过；来源的多样性没有上限——多一个生产者、多挂一个模型，整张网的可用性就抬高一格。

看一个网络抗不抗打，别看它的承诺，看它的账本：**出事的那几天，请求有没有接着流。**

最近，“Tibo 表示，从今天开始，只要你的付费 ChatGPT 账户尚未获得 Astra 权限，每天都会获得 1 张 Codex 重置卡。” 

用aweshare 分发，不仅codex 能用，opencode 也能用，集大家的力量把额度共享用完，而不用多花钱买账号，不是挺好？

## 试试

### 让 AI agent 帮你装

在 Claude Code、Codex 或任何编程 agent 里说一句：

```text
阅读 https://github.com/wehuman01/aweshare/blob/main/README.ai.md 并按它安装和配置 aweshare。
```

### 你也可以自己跑一个hub

```bash
npm install -g aweshare

# 运营者：一台小服务器，起自己的平台
aweshare hub init && aweshare hub serve

# 生产者：拨出去，接入任何一个 hub（包括你自己的）
aweshare producer init && aweshare producer start
```

想用现成的？社区平台在 [aweshare.wehuman.top](https://aweshare.wehuman.top)；想自己开一个？文档都在 [GitHub](https://github.com/wehuman01/aweshare)。

## 现在就申请

消费者 10 个名额，先到先得；生产者不设限，随时欢迎。

发邮件到 [peng@wehuman.top](mailto:peng@wehuman.top)，说明你是谁、想共享还是使用，以及准备接入什么后端。aweshare 本身的 bug 请提交至 [GitHub issues](https://github.com/wehuman01/aweshare/issues)。

## aweshare 系列文章

- [aweshare：迈入共享token 时代](https://mp.weixin.qq.com/s/zFRIuxdLj6F5vPj9P7rXAQ)
- [aweshare 社区：消费者 10 个名额，螃蟹先到的吃](https://mp.weixin.qq.com/s/iOU72DB-SESe4IktIIdvbQ)
- [aweshare 更新：剩余用量、延迟、诚实度，一条命令测完](https://mp.weixin.qq.com/s/4cOiTbxcJ9R7Ev6LHbUjgg)



## Awesome Ecosystem

aweshare 是一个不断壮大的 "awesome" 工具家族的一员 — CLI 优先、local-first，可被 AI agent 直接操作。

### CLI 工具

- **[aweskill](https://aweskill.webioinfo.top/)** — CLI 优先的技能包管理器，支持 47+ AI 编程 agent。
- **[aweswitch](https://github.com/Webioinfo01/aweswitch)** — Claude Code、Codex、OpenCode 的 agent 配置切换器。
- **[awerouter](https://github.com/mugpeng/awerouter)** — 智能路由器，用结构信号把请求分给 Flash 或 Pro 模型，减少不必要的模型开销。
- **[aweshelf](https://github.com/Webioinfo01/aweshelf)** — 收藏、分类、恢复 AI 编程会话，还能搭配 aweswitch 实现保存配置，一键启动。
- **[aweshare](https://github.com/wehuman01/aweshare)** — 通过自建 Hub 共享本地 Ollama/vLLM 或已授权的 OpenAI/Anthropic 后端，实现 token 的共享经济。
- **[awewarm](https://github.com/wehuman01/awewarm)** — 订阅窗口保持器，让 AI 编程套餐的窗口持续激活，无论是本地设置，还是通过远程连接的服务器。
- **[awescholar](https://github.com/Webioinfo01/awescholar)** — AI agent 可自主执行的科学文献发现与策展，搜索、标注、筛选和报告学术论文。

### 桌面应用

- **[awedot](https://awedot.wehuman.top/)** — 悬浮球驻留屏幕边缘，实时追踪当前 AI 会话；一键收藏、随时恢复，并可搭配 aweswitch 固定 agent 配置（比如用 GLM 模型启动）。

### 项目合集

- **[Awesome AI Meets Biology](https://github.com/Webioinfo01/Awesome-AI-Meets-Biology)** — AI 在生物学、生物信息学和生物医学研究中应用的精选综述。由 awescholar 驱动。
- **[Awesome AI Virtual Tumor](https://github.com/Webioinfo01/Awesome-AI-Virtual-Tumor)** — 面向虚拟肿瘤建模与仿真的前沿 AI 系统精选合集：静态模型、动态模型、agent、基准与综述。
