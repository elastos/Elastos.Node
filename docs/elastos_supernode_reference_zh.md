# CR委员认领超级节点搭建指南_v1.0.3

## 认领节点方式
1. EF代运营节点
2. CR委员运营节点

## CR委员超级节点组成

1. ela主链节点
2. did侧链节点
3. eth侧链节点
4. arbiter侧链节点
5. carrier节点

## 环境要求

- 操作系统: Ubuntu 18.04 LTS 64-bit、Ubuntu 20.04 LTS 64-bit
- CPU: 4核或4核以上
- 内存: 不小于16GB
- 硬盘: 不少于50GB
- 网络: aws标准网络，具有可访问的公网IP或域名
- 防火墙需要将ELAPort[TCP：20338、20339]、DIDPort[TCP：20608]、ETHPort[TCP：20639、20638,UDP：20638]、ArbiterPort[TCP：20538]和CarrierPort[UDP：3478、33445，TCP：33445]端口端口设置为全网开放
- 系统权限: 具有sudo权限

## EF代运营节点
1. 认领EF运营的CR节点，CR委员不需要搭建节点
2. CR委员联系CR秘书长申请dpos节点公钥
3. CR委员需要将dpos节点公钥填入Ela Wallet软件“CR领取节点”页面；CR委员需要在“CR委员会”的“委员管理”的“领取CR节点”页面填入该公钥。点击下一步需要输入支付密码，以保证更新的信息被提交并记录在区块链上


## CR委员运营节点

### 1. 搭建ela主链节点

#### 1.1 下载节点程序及默认配置文件

- ela、ela-cli 

    ```
    # 下载链接: 
       $ wget https://download.elastos.org/elastos-ela/elastos-ela-v0.7.0/elastos-ela-v0.7.0-linux-x86_64.tgz
    ```
    
- dpos_config.json.sample
  
    ```
    # 下载链接: 
        wget https://raw.githubusercontent.com/elastos/Elastos.ELA/master/docs/dpos_config.json.sample 
    # 配置文件的参数说明，请参考:
        https://github.com/elastos/Elastos.ELA/blob/master/docs/config.json.md
    ```

#### 1.2 将节点及配置文件拷贝至ela节点运行目录

- 创建节点运行目录 `mkdir ~/node/ela/ `
- 将ela节点程序、ela-cli、dpos_config.json.sample拷贝至ela节点目录，并将dpos_config.json.sample重命名为config.json
```bash
    mv ela ~/node/ela/
    mv ela-cli ~/node/ela/
    mv dpos_config.json.sample config.json
    mv config.json ~/node/ela/
```

#### 1.3 创建你keystore.dat文件

1. 将ela-cli拷贝至ela节点目录
2. 创建节点公钥keystore.dat文件

keystore.dat文件存储节点公钥，dpos超级节点使用该文件完成节点通信等业务。

创建keystore.dat文件的命令如下。该密码为该keystore.dat文件的加密密码，需要添加至ela节点启动命令中，建议设置具有一定加密强度的密码。

```bash
cd ~/node/ela/
# 执行命令后，将提示输入密码
./ela-cli wallet create
# 以明文的形式输入密码 
./ela-cli wallet create -p Password
```

3. 查看节点公钥

查看keystore.dat文件对应的公钥，该公钥为节点公钥，需要将该公钥提供给CR委员。**CR委员需要将该公钥填入“CR领取节点”页面；CR委员需要在“CR委员会”的“委员管理”的“领取CR节点”页面填入该公钥。点击下一步需要输入支付密码，以保证更新的信息被提交并记录在区块链上。**

```bash
# 执行命令后，将提示输入密码
./ela-cli wallet account
# 以明文的形式输入密码
./ela-cli wallet account -p Password
```

#### 1.4 修改ela配置文件config.json

- 复制dpos_config.json.sample至ela节点目录，并更名为config.json。
- 将"IPAddress"修改为服务器公网IP或域名。
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

节点启动后并同步完数据，ela-cli可查看节点高度、版本等信息

```bash
# 未设置User及Pass
./ela-cli info getnodestate
# 设置User及Pass，默认RPC端口为20336
./ela-cli --rpcport 20336 --rpcuser User --rpcpassword PASS info getnodestate
```

节点返回结果如下:

```json
{
    "compile": "v0.7.0",
    "height": 748443,
    "neighbors": [
        {
            "conntime": "2020-10-11 12:33:21.665770659 +0000 UTC m=+1542724.514426872",
            "inbound": true,
            "lastblock": 550168,
            "lastpingmicros": 11275,
            "lastpingtime": "2020-10-12 04:32:21.666297957 +0000 UTC m=+1600264.514954130",
            "lastrecv": "2020-10-12 04:32:41 +0000 UTC",
            "lastsend": "2020-10-12 04:32:41 +0000 UTC",
            "netaddress": "3.217.7.213:40496",
            "nodeversion": "ela-v0.7.0",
            "relaytx": false,
            "services": "SFNodeNetwork|SFTxFiltering|SFNodeBloom",
            "startingheight": 718443,
            "timeoffset": 0,
            "version": 80000
        }
    ],
    "port": 0,
    "restport": 20334,
    "rpcport": 20336,
    "services": "SFNodeNetwork|SFTxFiltering|SFNodeBloom",
    "version": 80000,
    "wsport": 20335
}
```

其他查询命令可以查看ela-cli使用文档:

CN:https://github.com/elastos/Elastos.ELA/blob/master/docs/cli_user_guide_CN.md EN:https://github.com/elastos/Elastos.ELA/blob/master/docs/cli_user_guide.md

3. log分析

ela节点的log记录与elastos/logs/目录下，其中node目录中为节点同步信息相关log，dpos目录为dpos共识相关log

如果为当选节点，可以看到类似如下log:

```
2020/10/12 04:02:20.399738 ^[[1;35m[INF]^[[m GID 19925790, [OnBlockReceived] listener received block
2020/10/12 04:02:20.399781 ^[[1;35m[INF]^[[m GID 31, [OnBlockReceived] start
2020/10/12 04:02:20.399849 ^[[1;35m[INF]^[[m GID 31, [ProcessHigherBlock] broadcast inv and try start new consensus
2020/10/12 04:02:20.399879 ^[[1;35m[INF]^[[m GID 31, [BroadcastMessage] msg: inv
2020/10/12 04:02:20.399963 ^[[1;35m[INF]^[[m GID 31, [BroadcastMessage] msg: inv
2020/10/12 04:02:20.400024 ^[[1;35m[INF]^[[m GID 31, [Normal][OnBlockReceived] received first unsigned block, start consensus
2020/10/12 04:02:20.400088 ^[[1;35m[INF]^[[m GID 31, [StartConsensus] consensus start
2020/10/12 04:02:20.405658 ^[[1;35m[INF]^[[m GID 31, [OnViewStarted] OnDutyArbitrator: 028f5a10a1cc857a7e4728e6889bad995c05301691eca0f32c622d215cc25eec61, StartTime: 2020-10-12 04:02:20.351 +0000 UTC, Offset: 0, Height: 550152
2020/10/12 04:02:20.405955 ^[[1;35m[INF]^[[m GID 31, [StartConsensus] consensus end
2020/10/12 04:02:20.406002 ^[[1;35m[INF]^[[m GID 31, [OnConsensusStarted] StartTime: 2020-10-12 04:02:20.356 +0000 UTC, Height: 550152
2020/10/12 04:02:20.406062 ^[[1;35m[INF]^[[m GID 31, [OnBlockReceived] end
…
2020/10/12 04:02:20.623722 ^[[1;35m[INF]^[[m GID 31, [OnVoteReceived] started
2020/10/12 04:02:20.623783 ^[[1;35m[INF]^[[m GID 31, [Normal-ProcessAcceptVote] start
2020/10/12 04:02:20.623829 ^[[1;35m[INF]^[[m GID 31, [Normal-ProcessAcceptVote] end
2020/10/12 04:02:20.623871 ^[[1;35m[INF]^[[m GID 31, [OnVoteArrived] Signer: 03b804eb218c971bde5709ab6cae6b729ab9b6373b9e9b29beee91b2e107b12752, ProposalHash: 37c2e1047b7b8122a9354207e9e9657db4994c2ea3e3cb00da0a45aaa58df60f, ReceivedTime: 2020-10-12 04:02:20.574 +0000 UTC, Result: true
020/10/12 04:02:20.624659 ^[[1;35m[INF]^[[m GID 31, [OnVoteReceived] end
2020/10/12 04:02:20.624708 ^[[1;35m[INF]^[[m GID 31, [OnVoteReceived] started
```

### 2. 搭建did侧链节点

#### 2.1 下载节点程序及默认配置文件

- did

    ```
    # 下载链接:
        $ wget  https://download.elastos.org/elastos-did/elastos-did-v0.2.1/elastos-did-v0.2.1-linux-x86_64.tgz ```

- mainnet_config.json.sample 

    ```
    # 下载链接:
        $ wget https://raw.githubusercontent.com/elastos/Elastos.ELA.SideChain.ID/master/docs/dpos_config.json.sample 
    # 配置文件的参数说明，请参考:
        https://github.com/elastos/Elastos.ELA.SideChain.ID/blob/master/docs/config.json.md  
    ```

#### 2.2 将节点及配置文件拷贝至did侧链节点运行目录

- 创建节点运行目录 ` mkdir ~/node/did/ `
- 将did节点程序、dpos_config.json.sample 拷贝至did侧链节点目录，并将dpos_config.json.sample重命名为config.json

```bash
    mv did ~/node/did/
    mv dpos_config.json.sample config.json
    mv config.json ~/node/did/
```

##### 2.2.1 修改配置文件

- 根据运维需要，修改RpcConfiguration中的"WhiteIPList"、"User"及"Pass"，访问规则与ela的RPC访问限制一致
- "PayToAddr"为矿工收益地址，务必填写自己保密的账户
- "MinerInfo"为矿工名称，请使用注册CR委员的名称

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

其他RPC接口请查阅 DID-RPC文档:https://github.com/elastos/Elastos.ELA.SideChain.ID/blob/master/docs/jsonrpc_apis.md

### 3. 搭建eth侧链节点

#### 3.1 下载节点程序及默认配置文件

- eth

    ```
    # 下载链接:
        $ wget https://download.elastos.org/elastos-eth/elastos-eth-v0.1.3.2/elastos-eth-v0.1.3.2-linux-x86_64.tgz
    ```

- oracle

    ```
    # 下载链接:
        $ wget https://github.com/elastos/Elastos.ELA.SideChain.ETH/releases/download/v0.1.1/oracle.tar.gz
    ```

- nodejs

    ```
    # 下载链接:
        $ wget https://npm.taobao.org/mirrors/node/v14.17.0/node-v14.17.0-linux-x64.tar.gz
    ```

#### 3.2 将节点及配置文件拷贝至did侧链节点运行目录

1. 创建节点运行目录 ` mkdir ~/node/eth/ `
2. 创建节点数据目录 ` mkdir -p ~/node/eth/data/ `
3. 创建日志目录 `mkdir -p  ~/node/eth/logs/ `
4. 将geth节点程序、oracle目录拷贝至eth侧链节点目录 

```bash
    mv geth ~/node/eth/
    mv oracle ~/node/eth/
```

5. 将ELA节点目录下的keystore.dat（dpos节点账户）拷贝至eth侧链节点目录 ` cp ~/node/ela/keystore.dat ~/node/eth/ `
6. 并将keystore.dat 密码存入到文件中 ` echo Password > ~/node/eth/ela.txt `

##### 3.2.1 创建矿工账户

1. eth侧链节点目录下生成矿工账户，命令: ` ./geth --datadir "~/node/eth/data/" account new `
2. 查看账户生成是否成功

```bash
cd ~/node/eth/data/keystore/

# 如出现UTC--2019-08-03T08-08-42.293003000Z--72064cd776e12d7163d329cc0* 格式表示创建成功
```
3. 将密码写入本地文件，命令: `echo password > ~/node/eth/eth.txt `

#### 3.3 安装oracle依赖包

1. 没有python2.7,安装python2.7: `sudo apt-get install -yq python-minimal python-dev make g++`
2. 安装nodejs,下载链接: `wget https://npm.taobao.org/mirrors/node/v10.13.0/node-v10.13.0-linux-x64.tar.gz`
3. 解压文件拷贝至eth侧链目录， 路径: ~/node/eth/
4. 安装web3: `npm install web3@1.2.1 --save -g`
5. 安装pm2: `npm install pm2@3.0.0 -g`
6. 安装express: `sudo npm install express@4.16.0`
7. 将node_modules依赖包目录拷贝至eth侧链节点目录 ` mv node_modules  ~/node/eth/ `

#### 3.4 运行eth侧链节点

1. 启动geth节点
geth节点启动命令:

```bash
# 启动命令
# --password "密码存放的文件路径" , 3.2.1中第3步骤的文件路径
# --pbft.keystore.password "密码存放的文件路径", ela节点启动密码(dpos节点账户密码), 3.2 中第6步骤的文件路径
nohup ./geth --datadir ~/node/eth/data \
    --mine --miner.threads 1 \
    --rpc --rpcvhosts '*' --rpcaddr "0.0.0.0" \
    --rpcapi "personal,db,eth,net,web3,txpool,miner" \
    --unlock "0x$(cat ~/node/eth/data/keystore/UTC* | jq -r .address)" \
    --password "密码存放的文件路径" \
    --pbft.keystore.password "密码存放的文件路径" \
    --pbft.net.address "$(curl ifconfig.me)" \
    --pbft.net.port 20639 \
    --allow-insecure-unlock \
    >>~/node/eth/logs/geth.log 2>&1 &
```

2. 查看eth节点高度

```bash
curl -H "Content-Type: application/json" -X POST -d '{"method":"eth_blockNumber", "id":1}'  http://127.0.0.1:20636  
```
其他RPC接口请查阅ETH-RPC文档:https://eth.wiki/json-rpc/API


#### 启动oracle服务

1. 启动关闭oracle服务
oracle服务启动命令:

```bash
# 启动命令
export PATH=~/node/eth/node-v10.13.0-linux-x64/bin:$PATH
export PATH=~/node/eth/node_modules/pm2/bin:$PATH

pm2 start ～/node/eth/oracle/crosschain_oracle.js -i 1 \
    -e ～/node/eth/logs/oracle_err.log \
    -o ～/node/eth/logs/oracle_out.log
```

2. 查看oracle服务状态

```bash
# 启动命令
export PATH=~/node/eth/node-v10.13.0-linux-x64/bin:$PATH 
export PATH=~/node/eth/node_modules/pm2/bin:$PATH
pm2 status 
```

```
# status显示 online 表示oracle启动成功
┌─────┬──────────────────────┬─────────────┬─────────┬─────────┬──────────┬────────┬──────┬───────────┬──────────┬──────────┬──────────┬──────────┐
│ id  │ name                 │ namespace   │ version │ mode    │ pid      │ uptime │ ↺    │ status    │ cpu      │ mem      │ user     │ watching │
├─────┼──────────────────────┼─────────────┼─────────┼─────────┼──────────┼────────┼──────┼───────────┼──────────┼──────────┼──────────┼──────────┤
│ 0   │ crosschain_oracle    │ default     │ 1.0.0   │ cluster │ 22473    │ 21D    │ 0    │ online    │ 0.5%     │ 52.1mb   │ dev      │ disabled │
└─────┴──────────────────────┴─────────────┴─────────┴─────────┴──────────┴────────┴──────┴───────────┴──────────┴──────────┴──────────┴──────────┘

```

### 4. 搭建arbiter仲裁人节点

#### 4.1 下载节点程序及默认配置文件

- arbiter

    ```
    # 下载链接:
        $ wget https://download.elastos.org/elastos-arbiter/elastos-arbiter-v0.2.1/elastos-arbiter-v0.2.1-linux-x86_64.tgz 
    ```
    
- coinfig.json
    ``` 
    # 下载链接:
        $ wget https://raw.githubusercontent.com/elastos/Elastos.ELA.Arbiter/master/docs/mainnet_config.json.sample 
    # 配置文件的参数说明，请参考:
        https://github.com/elastos/Elastos.ELA.Arbiter/blob/master/docs/config.json.md
    ```


#### 4.2 将节点及配置文件拷贝至arbiter仲裁人节点运行目录

- 创建节点运行目录，建议节点路径: ~/node/arbiter/
- 将arbiter节点、ela-cli、mainnet_config.json.sample拷贝至did侧链节点目录，并将mainnet_config.json.sample重命名为config.json
- 将ELA节点目录下的keystore.dat（dpos节点账户）拷贝至arbiter节点目录，并充值主链账户大于10ELA,用来侧链出块

#### 4.3 创建次账户

1. 在已有的keystore.dat主账户基础下，继续生成一个次账户，用来did出块使用 `./ela-cli wallet add -p Password`

#### 4.4 修改arbiter配置文件

```
# "MainNode"的"User"和"Pass"参数需要和ELA节点配置文件参数一致
# "SideNodeList"的"User"和"Pass"参数需要和侧链节点配置文件参数一致
# "HttpJsonPort": 20606 为did侧链的rpc端口，表示连接did节点
# "HttpJsonPort": 20632 为eth侧链的rpc端口，表示连接eth节点

{
  "Configuration": {
    "MainNode": {
      "Rpc": {
        "IpAddress": "127.0.0.1",
        "HttpJsonPort": 20336,
        "User": "User",
        "Pass": "Password"
      }
    },
    "SideNodeList": [{
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20606,
          "User": "User",
          "Pass": "Password"
        },
        "SyncStartHeight": 914300,
        "ExchangeRate": 1.0,
        "GenesisBlock": "56be936978c261b2e649d58dbfaf3f23d4a868274f5522cd2adb4308a955c4a3",
        "MiningAddr": "arbiter新生成次账户地址，用来did侧链出块",
        "PowChain": true,
        "PayToAddr": "did侧链节点矿工地址, did配置文件PayToAddr的地址"
      },
      {
        "Rpc": {
          "IpAddress": "127.0.0.1",
          "HttpJsonPort": 20632
        },
        "SyncStartHeight": 6551000,
        "ExchangeRate": 1.0,
        "GenesisBlock": "6afc2eb01956dfe192dc4cd065efdf6c3c80448776ca367a7246d279e228ff0a",
        "PowChain": false
      }
    ],
    "RpcConfiguration": {
      "User": "User",
      "Pass": "Password",
      "WhiteIPList": [
        "127.0.0.1"
      ]
    }
  }
}

```


#### 4.5 运行arbiter节点

1. 启动arbiter节点
arbiter节点启动命令:

```bash
# 启动命令
nohup ./arbiter > /dev/null 2>output &
```

2. 查看arbiter同步状态

```bash
# 查看同步ela节点高度
curl  -H  "Content-Type: application/json" -X POST -d '{"method":"getspvheight"}'  http://127.0.0.1:20536
# 查看同步did节点高度
curl  -H  "Content-Type: application/json" -X POST -d '{"method":"getsidechainblockheight", "params":{"hash":"56be936978c261b2e649d58dbfaf3f23d4a868274f5522cd2adb4308a955c4a3"}}'  http://127.0.0.1:20536
# 查看同步eth节点高度
curl  -H  "Content-Type: application/json" -X POST -d '{"method":"getsidechainblockheight", "params":{"hash":"6afc2eb01956dfe192dc4cd065efdf6c3c80448776ca367a7246d279e228ff0a"}}'  http://127.0.0.1:20536
```

其他RPC接口请查阅Arbiter-RPC文档:https://github.com/elastos/Elastos.ELA.Arbiter/blob/master/docs/jsonrpc_apis.md

### 5. 搭建carrier节点

#### 5.1 下载节点安装包

- carrier
  
     ``` https://github.com/elastos/Elastos.NET.Carrier.Bootstrap/releases/download/release-v5.2.3/elastos-carrier-bootstrap-5.2.623351-linux-x86_64-Debug.deb ```

#### 5.2 将节点安装包拷贝至carrier节点运行目录

- 创建节点运行目录，建议节点路径: ~/node/carrier/
- 将carrier节点安装包拷贝至carrier节点目录

#### 5.3 运行carrier节点

##### 5.3.1 启动carrier节点

```bash
$ sudo dpkg -i ~/node/carrier/elastos-carrier-bootstrap-5.2.623351-linux-x86_64-Debug.deb
```

##### 5.3.2 查看carrier节点状态

```bash
$ sudo systemctl status ela-bootstrapd
```

如果carrier节点正常运行, 会有如下打印：

 **active (running)**.

##### 5.3.3 配置文件

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

systemctl使用说明:https://www.freedesktop.org/software/systemd/man/systemctl.html
