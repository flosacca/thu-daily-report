#!/usr/bin/env ruby

require 'http'
require 'nokogiri'
require 'multi_json'
require 'jsonpath'

module Utils
  def assert(test)
    raise 'Assertion failed' unless test
  end
end

class Reporter
  include Utils

  ATTRIBUTES = Object.new.instance_eval do
    @service_id = 'b44e2daf-0ef6-4d11-a115-0eb0d397934f'
    @root_url = 'https://thos.tsinghua.edu.cn'
    @headers = {
      'User-Agent' => [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'AppleWebKit/537.36 (KHTML, like Gecko)',
        'Chrome/87.0.4280.141',
        'Safari/537.36'
      ].join(' '),
      'Accept' => '*/*',
      'Accept-Encoding' => 'gzip, deflate',
      'Accept-Language' => 'zh-CN,zh;q=0.9'
    }
    @cookies = []
    instance_variables.each_with_object({}) do |k, h|
      h[k] = instance_variable_get(k)
    end
  end

  ATTRIBUTES.each_key do |key|
    attr_reader key.to_s[1..-1]
  end

  def initialize
    ATTRIBUTES.each do |k, v|
      instance_variable_set(k, v)
    end
  end

  def http
    HTTP.timeout(10)
      .use(:auto_inflate)
      .headers(headers)
      .cookies(cookies)
  end

  def login(username, password)
    return unless cookies.empty?

    # 从服务页面重定向到登录页面
    # 登录页面的地址与服务页面的子域名相关，因此通过重定向间接访问
    res = http.follow.get(root_url + '/fp/')
    assert res.code == 200
    @cookies = res.cookies

    # 需要使用 GET 登录页面返回的 cookie 才能正确登录
    # 诡异的是，即使指定使用过的此前返回的 cookie，也需要 GET
    # 一次登录页面，否则会登录失败
    url = 'https://id.tsinghua.edu.cn/do/off/ui/auth/login/check'
    res = http.headers({
      'Referer' => res.uri.to_s
    }).post(url, form: {
      i_user: username,
      i_pass: password
    })
    assert res.code == 200
    doc = Nokogiri::HTML(res.to_s)
    assert doc.at('.form-signin').nil?
    @cookies = res.cookies

    # 上一个请求返回 HTML，包含一个中间地址
    # 这个地址的查询参数包含一个 ticket，GET 这个地址返回最终需要的 cookie
    url = doc.at('a')['href']
    res = http.get(url)
    assert res.code == 302
    @cookies = res.cookies
  end

  def submit
    http = self.http.persistent(root_url)

    res = http.post('/fp/fp/serveapply/getServeApply', json: {
      serveID: service_id,
      from: 'hall'
    })
    assert res.code == 200
    res = MultiJson.load(res.to_s)
    form_id = res['formID']
    proc_id = res['procID']
    # privilege_id = res['privilegeID']

    qs = URI.encode_www_form({
      status: 'select',
      formid: form_id
    })
    res = http.get('/fp/formParser?' + qs)
    assert res.code == 200
    doc = Nokogiri::HTML(res.to_s)
    data = doc.at('#dcstr').text
    data.gsub!(/\b\w+\b(?=\s*:)/, '"\&"')
    data = MultiJson.load(data)

    data = %i[
      ID_NUMBER USER_NAME UNIT_NAME BJ DH XQ
      YHLB SFQRZ XSSF JRSZD MQXXSZ JCXQK SFGFXDQ JKQK
    ].each_with_object({}) do |k, h|
      p = '$..primary[?(@.name =~ /\b%s\z/)].value'
      h[k] = JsonPath.new(p % k).first(data)
    end
    data[:ts] = '%.f' % [Time.now.to_f * 1000]
    data = File.read('tpl.txt') % data

    res = http.headers({
      'Content-Type' => 'text/plain;charset=UTF-8',
      'Referer' => res.uri.to_s
    }).post('/fp/formParser', {
      params: {
        status: 'update',
        formid: form_id,
        workflowAction: 'startProcess',
        seqId: '',
        workitemid: '',
        process: proc_id
      },
      body: data
    })
    assert res.code == 200

    res = http.headers({
      'Referer' => root_url + '/fp/view?m=fp'
    }).post('/fp/fp/formHome/updateVisit', json: {
      server_id: service_id
    })
    assert res.code == 200
  end
end

5.times do
  begin
    r = Reporter.new
    r.login(ENV['USERNAME'], ENV['PASSWORD'])
    r.submit
    break
  rescue StandardError
    next
  end
end
