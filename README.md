hunt
=======

A web framework based on [Collie](https://github.com/putao-dev/collie/), written in [dlang](http://dlang.org/).

## 建议

- 模板文件存放在[./resources/views]此目录下，如需修改可以在dub.json中修改【"stringImportPaths":  [ "./resources/views"],】此项
- 格式化代码命令： dfmt --inplace --tab_width=4 --brace_style=allman *.d

## Router

config/routes/default.conf
```conf
GET     /               module/controller/action 
POST    /user/add       account/user/add    before:GlobalMiddleware,CheckMiddleware;after:EndMiddleware
GET     /user/view/{:id}  account/user/view
```
config/routes/admin.conf
```conf
GET     /               module/controller/action
POST    /user/add       account/user/add
GET     /user/view/{:id}  account/user/view
```

