#!/usr/bin/env ruby

require 'http'
require 'nokogiri'

class Reporter
  @service_id = 'b44e2daf-0ef6-4d11-a115-0eb0d397934f'
  @base_url = 'https://thos.tsinghua.edu.cn/fp/view?m=fp'
  @service_url = "#{@base_url}#from=hall&serveID=#{@service_id}&act=fp/serveapply"

  class << self
    attr_reader :service_id, :base_url
    attr_accessor :form_id, :process_id

    def assert(truth)
      raise 'Assertion failed' unless truth
    end

    def http
      HTTP.use(:auto_inflate).headers({
        'User-Agent' => [
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          'AppleWebKit/537.36 (KHTML, like Gecko)',
          'Chrome/87.0.4280.141',
          'Safari/537.36'
        ].join(' '),
        'Accept' => '*/*',
        'Accept-Encoding' => 'gzip, deflate',
        'Accept-Language' => 'zh-CN,zh;q=0.9'
      })
    end

    def login(username, password)
      # 从服务页面重定向到登录页面
      # 登录页面的地址与服务页面的子域名相关，因此通过重定向间接访问
      res = http.follow.get(base_url)
      assert res.code == 200

      # 需要使用 GET 登录页面返回的 cookie 才能正确登录
      # 诡异的是，如果指定使用过的此前返回的 cookie，也需要 GET 一次登录页面，否则会登录失败
      url = 'https://id.tsinghua.edu.cn/do/off/ui/auth/login/check'
      res = http.headers(referer: res.uri.to_s)
        .cookies(res.cookies)
        .post(url, form: {
          i_user: username,
          i_pass: password
        })
      assert res.code == 200

      # 上一个请求返回 HTML，包含一个中间地址
      # 这个地址的查询参数包含一个 ticket，GET 这个地址返回最终需要的 cookie
      url = Nokogiri::HTML(res.to_s).at('a')['href']
      res = http.get(url)
      assert res.code == 302
      @cookies = res.cookies
    end
  end
end
