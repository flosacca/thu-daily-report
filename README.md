# thu-daily-report

受[北邮相关项目](https://github.com/imtsuki/bupt-ncov-report-action)启发，使用 GitHub Actions 自动填报清华大学健康日报（学生健康及出行情况报告），每天自动在北京时间上午 8 点进行填报。

## 注意事项

[某既存项目](https://github.com/naihaishy/TsinghuaDailyReport)提交的表单疑似无效：会显示在办结事项中，但是不能正确更新后台记录。

本项目将实际提交的表单作为[模板](tpl.txt)，理论上不会有问题，不过只填写了在校内时需要填写的项目。

## 使用方法

点击页面上方绿色的 **Use this template**，使用这个模板创建你自己的仓库；

在你自己仓库的 Settings 的 Secrets 中设置以下信息：

- `USERNAME`: 你用来登录的用户名；
- `PASSWORD`: 你用来登录的密码。

## 高级设置

你可以在 `.github/workflows/main.yml` 中设置每天运行的时间：

```yml
schedule:
  - cron: '0 0 * * *'
```

格式是标准的 cron 格式，第一个数字代表分钟，第二个数字代表小时。例如，`0 23 * * *` 表示每天在 UTC 23:00，也就是在北京时间次日 07:00 自动运行。
