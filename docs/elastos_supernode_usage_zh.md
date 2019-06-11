# Elastos Supernode Usage

## 1. 安装

### 1.1. 下载节点压缩包

下载节点tgz压缩包。

```bash
$ wget https://download.elastos.org/supernode/elastos-supernode-20190609-alpha.tgz
```

### 1.2. 验证压缩包是否正确

```bash
$ wget https://download.elastos.org/supernode/elastos-supernode-20190609-alpha.tgz.digest
$ shasum -c elastos-supernode-20190609-alpha.tgz.digest
```

### 1.3. 验证PGP签名

```bash
$ wget node.tar.gz.asc
$ pgp -v node.tar.gz.asc
```

### 1.4. 解压压缩包

```bash
$ tar xf elastos-supernode-20190609-alpha.tgz
```

解压后将得到与node/readme.txt文件一致的目录结构。

### 1.5. 验证压缩包内容是否正确

```bash
$ cd ~/node
$ shasum -c checksum.txt
$ find node
```

如下输出结果表明压缩包内容验证成功。

```
node.sh: OK
ela/ela: OK
did/did: OK
token/token: OK
carrier/ela-bootstrapd: OK
```

## 2. Running

`~/node/node.sh` 是运行与维护节点的主要脚本。可以使用这个脚本完成节点初始化、启动、关闭等操作。

### 2.1. Configure

```bash
$ ~/node/node.sh init
```

输入用于创建keystore.dat文件的密码，然后 `~/node/node.sh` 将自动获取服务器的公网IP并使用该IP完成配置文件的修改。

**必须记录 `PUBLIC KEY` 对应的公钥，该公钥为节点公钥，需要将该公钥提供给候选人。候选人需要将该公钥填入“报名参选”页面；已注册候选人需要在“选举管理”的“更新信息”页面填入该公钥，并更新信息。点击更新信息后需要再次输入支付密码，以保证更新的信息被提交并记录在区块链上。**

```
Please enter your password for keystore.dat: Creating keystore.dat...
ADDRESS                            PUBLIC KEY
---------------------------------- ------------------------------------------------------------------
EfXimFfnNL8Cw5U2xkHYabvnJ5JDQYucA3 0312dba0fab6572d56b6f707866814924efd42354cb740fafc842d79d2c2bcd761
---------------------------------- ------------------------------------------------------------------
Done
Updating /node/ela/config.json...
Done

Updating /node/carrier/bootstrapd.conf...
Done
```

### 2.2. 启动节点

```bash
$ ~/node/node.sh start
```

如下输出表示节点正常启动。

```
Starting ela...
ela: Running, 29709
Starting did...
did: Running, 29723
Starting token...
token: Running, 29736
Starting carrier...
Elastos bootstrap daemon, version 5.2(20190604)
carrier: Running, 2493, 2495
```

### 2.3. 关闭节点

关闭ela、did、token及carrier节点。

```bash
$ ~/node/node.sh stop
```

如果节点正常关闭，屏幕将显示如下输出。

```
Stopping ela...
ela: Stopped
Stopping did...
did: Stopped
Stopping token...
token: Stopped
Stopping carrier...
carrier: Stopped
```

### 2.4. 节点状态

查看节点状态

```bash
$ ~/node/node.sh status
```

如果得到如下输出，表示节点运行正常。

```
ela: Running, 29709
did: Running, 29723
token: Running, 29736
carrier: Running, 2493, 2495
```

如果输出如下，表示节点已关闭。

```
ela: Stopped
did: Stopped
token: Stopped
carrier: Stopped
```

## 3. Maintanence

### 3.1. Monitoring

TODO

### 3.2. Upgrading

TODO

### 3.3. Diagnostic

TODO

