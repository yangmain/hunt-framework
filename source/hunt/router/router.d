module hunt.router.router;

import std.regex;

import hunt.router.middleware;
import hunt.router.utils;

final shared class Router(REQ, RES)
{
    alias HandleDelegate = void delegate(REQ, RES);
    alias Pipeline = PipelineImpl!(REQ, RES);
    alias PipelineFactory = IPipelineFactory!(REQ, RES);
    alias RouterElement = PathElement!(REQ, RES);
    alias RouterMap = ElementMap!(REQ, RES);

    void setGlobalBeforePipelineFactory(PipelineFactory before)
    {
        _gbefore = before;
    }

    void setGlobalAfterPipelineFactory(PipelineFactory after)
    {
        _gafter = after;
    }

    RouterElement addRouter(string method, string path, HandleDelegate handle,
        shared PipelineFactory before = null, shared PipelineFactory after = null)
    {
        if (condigDone)
            return null;
        auto map = _map.get(method, null);
        if (!map)
        {
            map = new RouterMap(this);
            _map[method] = map;
        }
        map.add(path, handle, before, after);
    }

    Pipeline match(string method, string path)
    {
        if (!condigDone)
            return null;
        auto map = _map.get(method, null);
        if (!map)
            return null;
        return map.match(path);
    }

    Pipeline getGlobalBrforeMiddleware()
    {
        if (_gbefore)
            return _gbefore.newPipeline();
        else
            return null;
    }

    Pipeline getGlobalAfterMiddleware()
    {
        if (_gafter)
            return _gafter.newPipeline();
        else
            return null;
    }

    @property bool condigDone()
    {
        return _configDone;
    }

    void done()
    {
        _configDone = true;
    }

private:
    PipelineFactory _gbefore = null;
    PipelineFactory _gafter = null;
    RouterMap[string] _map;
    bool _configDone = false;
}

shared class PathElement(REQ, RES)
{
    alias HandleDelegate = void delegate(REQ, RES);
    alias Pipeline = PipelineImpl!(REQ, RES);
    alias PipelineFactory = Pipeline delegate();

    this(string path)
    {
        _path = path;
    }

    PathElement!(REQ, RES) macth(string path, Pipeline pipe)
    {
        return this;
    }

    final @property path() const
    {
        return _path;
    }

    final @property handler() const
    {
        return _handler;
    }

    final @property handler(HandleDelegate handle)
    {
        _handler = handle;
    }

    final Pipeline getBeforeMiddleware()
    {
        if (_before)
            return _before.newPipeline();
        else
            return null;
    }

    final Pipeline getAfterMiddleware()
    {
        if (_after)
            return _after.newPipeline();
        else
            return null;
    }

    final void setBeforePipelineFactory(shared PipelineFactory before)
    {
        _before = before;
    }

    final void setAfterPipelineFactory(shared PipelineFactory after)
    {
        _after = after;
    }

private:
    string _path;
    HandleDelegate _handler = null;
    shared PipelineFactory _before = null;
    shared PipelineFactory _after = null;
}

private:

final shared class RegexElement(REQ, RES) : PathElement!(REQ, RES)
{
    this(string path)
    {
        super(path);
    }

    override PathElement!(REQ, RES) macth(string path, Pipeline pipe)
    {
        auto rg = regex(compiledRoute.regex, "s");
        auto mt = matchFirst(path, _reg);
        if (!mt)
        {
            return null;
        }
        foreach (attr; _reg.namedCaptures)
        {
            pipe.addMatch(attr, mt[attr]);
        }
        return this;
    }

private:
    bool setRegex(string regex)
    {
        if (regex.length == 0)
            return false;
        _reg = buildRegex(regex);
        if(_reg.length == 0) return false;
        auto r = regex(_reg);
        if(!r.empty) return false;
        return true;
    }

    string _reg;
}

final shared class RegexMap(REQ, RES)
{
    alias RElement = RegexElement!(REQ, RES);
    alias PElement = PathElement!(REQ, RES);
    alias RElementMap = RegexMap!(REQ, RES);
    alias Pipeline = PipelineImpl!(REQ, RES);

    this(string path)
    {
        super(path);
    }

    PElement add(RElement ele, string preg)
    {
        string rege;
        string str = getFristPath(preg, rege);
        if (str.length == 0)
        {
            ele.destroy;
            return null;
        }
        if (isHaveRegex(str))
        {
            if (!ele.setRegex(preg))
                return null;

            bool isHas = false;
            for (int i = 0; i < _list.length; ++i) //添加的时候去重
            {
                if (_list[i].path == ele.path)
                {
                    isHas = true;
                    auto tele = _list[i];
                    _list[i] = ele;
                    tele.destroy;
                }
            }
            if (!isHas)
            {
                _list ~= ele;
            }
            return ele;
        }
        else
        {
            RElementMap map = _map.get(str, null);
            if (!map)
            {
                map = new RElementMap(str);
                _map[str] = map;
            }
            return map.add(ele, rege);
        }
    }

    PElement macth(string path, Pipeline pipe)
    {
        if (path.length == 0)
            return null;
        string lpath;
        string frist = getFristPath(path, lpath);
        if (frist.length == 0)
            return null;
        RElementMap map = _map.get(frist, null);
        if (map)
        {
            return map.macth(lpath, pipe);
        }
        else
        {
            foreach (ele; RElement)
            {
                auto element = ele.macth(path, pipe);
                if (element)
                {
                    return element;
                }
            }
        }
        return null;
    }

private:
    RElementMap[string] _map;
    RElement[] _list;
}

final class ElementMap(REQ, RES)
{
    alias RElement = RegexElement!(REQ, RES);
    alias PElement = PathElement!(REQ, RES);
    alias RElementMap = RegexMap!(REQ, RES);
    alias Pipeline = PipelineImpl!(REQ, RES);
    alias Route = Router!(REQ, RES);
    alias HandleDelegate = void delegate(REQ, RES);
    alias Pipeline = PipelineImpl!(REQ, RES);
    alias PipelineFactory = Pipeline delegate();

    this(Route router)
    {
        _router = router;
        _regexMap = new RElementMap("/");
    }

    PElement add(string path, HandleDelegate handle, PipelineFactory before, PipelineFactory after)
    {
        if (isHaveRegex(path))
        {
            auto ele = new RElement(path);
            ele.setAfterPipelineFactory(after);
            ele.setBeforePipelineFactory(before);
            ele.handler = handle;
            _regexMap.add(ele, path);
        }
        else
        {
            auto ele = new PElement(path);
            ele.setAfterPipelineFactory(after);
            ele.setBeforePipelineFactory(before);
            ele.handler = handle;
            _pathMap[path] = ele;
        }
    }

    Pipeline macth(string path)
    {
        Pipeline pipe = new Pipeline();

        PElement element = _pathMap.get(path, null);

        if (!element)
        {
            element = _regexMap.macth(path, pipe);
        }

        if (element)
        {
            pipe.append(_router.getGlobalBrforeMiddleware());
            pipe.append(element.getBeforeMiddleware());
            pipe.addHander(element.handler);
            pipe.append(element.getAfterMiddleware());
            pipe.append(_router.getGlobalAfterMiddleware());

        }
        else
        {
            pipe.destroy;
            pipe = null;
        }
        return pipe;
    }

private:
    Route _router;
    PElement[string] _pathMap;
    RElementMap _regexMap;
}
