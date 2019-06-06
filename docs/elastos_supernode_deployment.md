# elastos超级节点搭建指南_v1.0.1

本文档主要用于elastos超级节点的搭建。

## 超级节点组成

1. ela主链节点
2. did侧链节点
3. token侧链节点
4. carrier节点

## 环境要求

- 系统: Ubuntu 14.04 LTS 64-bit
- CPU: 2核或2核以上
- 内存: 不小于4GB
- 硬盘: 不少于40GB
- 网络: aws标准网络，具有可访问的公网IP或域名
- 防火墙需要将ELAPort[TCP：20338、20339]和CarrierPort[UDP：3478、33445，TCP：33445]端口设置为全网开放
- 系统权限: 具有sudo权限

## 搭建节点

### 1. 搭建ela主链节点

#### 1.1 下载节点程序及默认配置文件

- [ela](https://github.com/elastos/Elastos.ELA/releases/download/v0.3.2/ela)
- [ela-cli](https://github.com/elastos/Elastos.ELA/releases/download/v0.3.2/ela-cli)
- [dpos_config.json.sample](https://raw.githubusercontent.com/elastos/Elastos.ELA/master/docs/dpos_config.json.sample)

#### 1.2 将节点及配置文件拷贝至ela节点运行目录

- 创建节点运行目录，建议节点目录: ~/node/ela/
- 将ela节点程序、dpos_config.json.sample拷贝至ela节点目录，并将dpos_config.json.sample重命名为config.json

#### 1.3 创建你keystore.dat文件

1. 将ela-cli拷贝至ela节点目录
2. 创建节点公钥keystore.dat文件

keystore.dat文件存储节点公钥，dpos超级节点使用该文件完成节点通信等业务。

创建keystore.dat文件的命令如下。该密码为该keystore.dat文件的加密密码，需要添加至ela节点启动命令中，建议设置具有一定加密强度的密码。

```bash
# 执行命令后，将提示输入密码
./ela-cli wallet create
# 以明文的形式输入密码elastos
./ela-cli wallet create -p elastos
```

3. 查看节点公钥

查看keystore.dat文件对应的公钥，该公钥为节点公钥，需要将该公钥提供给候选人。**候选人需要将该公钥填入“报名参选”页面；已注册候选人需要在“选举管理”的“更新信息”页面填入该公钥，并更新信息。点击更新信息后需要再次输入支付密码，以保证更新的信息被提交并记录在区块链上。**

```bash
# 执行命令后，将提示输入密码
./ela-cli wallet account
# 以明文的形式输入密码elastos
./ela-cli wallet account -p elastos
```

#### 1.4 修改ela配置文件config.json

- 复制dpos_config.json.sample至ela节点目录，并更名为config.json。
- 将"IPAddress"修改为服务器公网IP或域名
- "RpcConfiguration"为对RPC接口的访问限制
  - "WhiteIPList"为允许访问本ela节点的IP白名单，"0.0.0.0"表示不限制访问IP
  - "User"与"Pass"为访问RPC接口的用户名及密码，如设置为""，则无需用户名密码即可访问
  - "WhiteIPList"与"User"、"Pass"必须同时满足，才能访问RPC接口
  - **RPC接口具有一定的控制权限，请妥善设置RPC接口访问权限**

#### 1.5 运行ela节点

1. 启动ela节点

ela节点启动命令中需要输入keystore.dat文件的密码，可以将该密码添加至ela节点启动命令:

```bash
# 启动命令，本示例中keystore.dat密码为elastos
echo elastos | nohup ./ela > /dev/null 2>output &
```

2. 查询节点信息

节点启动后，可以同ela-cli查看节点高度、版本等信息

```bash
# 未设置User及Pass
./ela-cli info getnodestate
# 设置User及Pass，并修改RpcPort为30336(默认RPC端口为20336)
./ela-cli --rpcport 30336 --rpcuser User --rpcpassword PASS info getnodestate
```

节点返回结果如下:

```json
{
    "compile":"v0.3.2",
    "height":230913,
    "neighbors":[
        {
            "conntime":"2019-04-25 09:59:04.559138458 +0000 UTC m=+184952.601678086",
            "inbound":false,
            "lastblock":230913,
            "lastpingmicros":11290,
            "lastpingtime":"2019-04-26 06:36:34.571244957 +0000 UTC m=+259202.613784567",
            "lastrecv":"2019-04-26 06:36:34 +0000 UTC",
            "lastsend":"2019-04-26 06:36:34 +0000 UTC",
            "netaddress":"18.208.17.78:22338",
            "relaytx":false,
            "services":"SFNodeNetwork|SFTxFiltering|SFNodeBloom",
            "startingheight":230913,
            "timeoffset":0,
            "version":20000
        },
        {
            "conntime":"2019-04-26 00:08:13.830248318 +0000 UTC m=+235901.872787897",
            "inbound":false,
            "lastblock":230913,
            "lastpingmicros":11295,
            "lastpingtime":"2019-04-26 06:36:43.842142254 +0000 UTC m=+259211.884681888",
            "lastrecv":"2019-04-26 06:36:43 +0000 UTC",
            "lastsend":"2019-04-26 06:36:43 +0000 UTC",
            "netaddress":"34.225.140.100:22338",
            "relaytx":false,
            "services":"SFNodeNetwork|SFTxFiltering|SFNodeBloom",
            "startingheight":230913,
            "timeoffset":0,
            "version":20000
        }
    ],
    "port":22338,
    "restport":0,
    "rpcport":22336,
    "services":"SFNodeNetwork|SFTxFiltering|SFNodeBloom",
    "version":20000,
    "wsport":0
}
```

其他查询命令可以查看ela-cli使用文档[CN](https://github.com/elastos/Elastos.ELA/blob/master/docs/cli_user_guide_CN.md) [EN](https://github.com/elastos/Elastos.ELA/blob/master/docs/cli_user_guide.md)

3. log分析

ela节点的log记录与elastos/logs/目录下，其中node目录中为节点同步信息相关log，dpos目录为dpos共识相关log

如果为当选节点，可以看到类似如下log:

```
2019/05/31 02:44:11.460839 [INF] GID 400, [OnBlockReceived] listener received block
2019/05/31 02:44:11.460875 [INF] GID 32, [OnBlockReceived] start
2019/05/31 02:44:11.460903 [INF] GID 32, [ProcessHigherBlock] broadcast inv and try start new consensus
2019/05/31 02:44:11.460946 [INF] GID 32, [BroadcastMessage] msg: inv
2019/05/31 02:44:11.460999 [INF] GID 32, [Normal][OnBlockReceived] received first unsigned block, start consensus
2019/05/31 02:44:11.461030 [INF] GID 32, [StartConsensus] consensus start
2019/05/31 02:44:11.461096 [INF] GID 32, [OnViewStarted] OnDutyArbitrator: 03488b0aace5fe5ee5a1564555819074b96cee1db5e7be1d74625240ef82ddd295, StartTime: 2019-05-31 02:44:11.451 +0000 UTC, Offset: 0, Height: 234655
2019/05/31 02:44:11.461130 [INF] GID 32, [StartConsensus] consensus end
2019/05/31 02:44:11.461196 [INF] GID 32, [OnBlockReceived] end
2019/05/31 02:44:11.815189 [INF] GID 32, [OnProposalReceived] started
2019/05/31 02:44:11.815229 [INF] GID 32, [Normal][ProcessProposal] start
2019/05/31 02:44:11.815270 [INF] GID 32, [ProcessProposal] start
2019/05/31 02:44:11.815611 [INF] GID 32, [TryStartSpeculatingProposal] start
2019/05/31 02:44:11.815655 [INF] GID 32, [TryStartSpeculatingProposal] end
2019/05/31 02:44:11.815702 [INF] GID 32, [acceptProposal] start
2019/05/31 02:44:11.815750 [INF] GID 32, [ProcessVote] start
2019/05/31 02:44:11.816032 [INF] GID 32, [countAcceptedVote] start
2019/05/31 02:44:11.816084 [INF] GID 32, [countAcceptedVote] Received needed sign, collect it into AcceptVotes!
2019/05/31 02:44:11.816160 [INF] GID 32, [countAcceptedVote] end
2019/05/31 02:44:11.816206 [INF] GID 32, [ProcessVote] end
…
22019/05/31 02:44:11.865495 [INF] GID 32, [OnVoteReceived] started
2019/05/31 02:44:11.865530 [INF] GID 32, [Normal-ProcessAcceptVote] start
2019/05/31 02:44:11.865568 [INF] GID 32, [ProcessVote] start
2019/05/31 02:44:11.865908 [INF] GID 32, [countAcceptedVote] start
2019/05/31 02:44:11.865955 [INF] GID 32, [countAcceptedVote] Received needed sign, collect it into AcceptVotes!
2019/05/31 02:44:11.865997 [INF] GID 32, Collect majority signs, finish proposal.
2019/05/31 02:44:11.866039 [INF] GID 32, [FinishProposal] start
2019/05/31 02:44:11.866097 [INF] GID 32, [AppendConfirm] append confirm.
2019/05/31 02:44:11.866202 [INF] GID 32, [FinishConsensus] start
2019/05/31 02:44:11.866242 [INF] GID 32, [onDutyArbitratorChanged] not onduty
2019/05/31 02:44:11.866324 [INF] GID 32, Clean proposals
2019/05/31 02:44:11.866363 [INF] GID 32, [FinishConsensus] end
2019/05/31 02:44:11.866398 [INF] GID 32, [FinishProposal] end
2019/05/31 02:44:11.866430 [INF] GID 32, [countAcceptedVote] end
2019/05/31 02:44:11.866460 [INF] GID 32, [ProcessVote] end
2019/05/31 02:44:11.866488 [INF] GID 32, [Normal-ProcessAcceptVote] end
```

### 2. 搭建did侧链节点

#### 2.1 下载节点程序及默认配置文件

- [did](https://github.com/elastos/Elastos.ELA.SideChain.ID/releases/download/v0.1.2/did)
- [mainnet_config.json.sample](https://raw.githubusercontent.com/elastos/Elastos.ELA.SideChain.ID/master/docs/mainnet_config.json.sample)

#### 2.2 将节点及配置文件拷贝至did侧链节点运行目录

- 创建节点运行目录，建议节点路径: ~/node/did/
- 将did节点程序、mainnet_config.json.sample拷贝至did侧链节点目录，并将mainnet_config.json.sample重命名为config.json

##### 2.2.1 修改配置文件

- 根据运维需要，修改RpcConfiguration中的"WhiteIPList"、"User"及"Pass"，访问规则与ela的RPC访问限制一致

#### 2.3 运行did侧链节点

1. 启动did节点
did节点启动命令:

```bash
# 启动命令
nohup ./did > /dev/null 2>output &
```

2. 查看did节点状态

```bash
# 通过RPC接口查看节点状态，需根据配置情况修改Authorization
curl -X POST \
  http://localhost:20606 \
  -H 'Authorization: Basic ZWxhOmVsYQ==' \
  -H 'Content-Type: application/json' \
  -d '{"method":"getnodestate"}'
```

其他RPC接口请查阅[DID-RPC文档](https://github.com/elastos/Elastos.ELA.SideChain.ID/blob/master/docs/jsonrpc_apis.md)

### 3. 搭建token侧链节点

#### 3.1 下载节点程序及默认配置文件

- [token](https://github.com/elastos/Elastos.ELA.SideChain.Token/releases/download/v0.1.2/token)
- [mainnet_config.json.sample](https://raw.githubusercontent.com/elastos/Elastos.ELA.SideChain.Token/master/docs/mainnet_config.json.sample)

#### 3.2 将节点及配置文件拷贝至token侧链节点运行目录

- 创建节点运行目录，建议节点路径: ~/node/token/
- 将token节点程序、mainnet_config.json.sample拷贝至token侧链节点目录，并将mainnet_config.json.sample重命名为config.json

##### 3.2.1 修改配置文件

- 根据运维需要，修改RpcConfiguration中的"WhiteIPList"、"User"及"Pass"，访问规则与ela的RPC访问限制一致

#### 3.3 运行token侧链节点

1. 启动token节点
token节点启动命令:

```bash
# 启动命令
nohup ./token > /dev/null 2>output &
```

2. 查看token节点状态

```bash
# 通过RPC接口查看节点状态，需根据配置情况修改Authorization
curl -X POST \
  http://localhost:20616 \
  -H 'Authorization: Basic ZWxhOmVsYQ==' \
  -H 'Content-Type: application/json' \
  -d '{"method":"getnodestate"}'
```

其他RPC接口请查阅[TOKEN-RPC文档](https://github.com/elastos/Elastos.ELA.SideChain.Token/blob/master/docs/jsonrpc_apis.md)

### 4. 搭建carrier节点

#### 4.1 下载节点安装包

- [carrier](https://github.com/elastos/Elastos.NET.Carrier.Bootstrap/releases/download/release-v5.2.3/elastos-carrier-bootstrap-5.2.623351-linux-x86_64-Debug.deb)

#### 4.2 将节点安装包拷贝至carrier节点运行目录

- 创建节点运行目录，建议节点路径: ~/node/carrier/
- 将carrier节点安装包拷贝至carrier节点目录

#### 4.3 运行carrier节点

##### 4.3.1 启动carrier节点

```bash
$ sudo dpkg -i ~/node/carrier/elastos-carrier-bootstrap-5.2.623351-linux-x86_64-Debug.deb
```

##### 4.3.2 查看carrier节点状态

```bash
$ sudo systemctl status ela-bootstrapd
```

如果carrier节点正常运行, 会有如下打印：

 **active (running)**.

##### 4.3.3 配置文件

配置文件: /etc/elastos/bootstrapd.conf

如果服务器无法获取到公网IP，则需要手动修改配置文件，将external_ip设置为真实的公网IP

```
turn = {
  port = 3478
  realm = "elastos.org"
  pid_file_path = "/var/run/ela-bootstrapd/turnserver.pid"
  userdb = "/var/lib/ela-bootstrapd/db/turndb"
  verbose = true
  external_ip = "X.X.X.X"
}
```

修改配置文件后，需要重启服务

```bash
$ sudo systemctl restart ela-bootstrapd
```

[systemctl使用说明](https://www.freedesktop.org/software/systemd/man/systemctl.html)
