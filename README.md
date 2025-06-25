# scripts
一些常用的脚本封装

## git
### git-clone-dir.sh
签出指定目录的Git仓库脚本

#### 使用语法
```bash
./git-clone-dir.sh [选项] <仓库URL> [目录列表|文件路径]
```

#### 选项说明
| 选项       | 描述                          | 示例                          |
|------------|-------------------------------|-------------------------------|
| `-h`       | 显示帮助信息                  | `./git-clone-dir.sh -h`       |
| `-f <文件>`| 从文件读取目录列表（每行一个目录）| `./git-clone-dir.sh -f dirs.txt repo` |
| `-c <目录>`| 指定目标克隆目录（默认使用仓库名）| `./git-clone-dir.sh -c my-repos repo dir1 dir2` |

#### 示例
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/taodev/scripts/main/git/git-clone-dir.sh) repo dir1
```