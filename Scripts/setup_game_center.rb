# frozen_string_literal: true

# App Store Connect API で Game Center のリーダーボードを作成する。
# 使い方: bundle exec ruby Scripts/setup_game_center.rb <ASC App ID>
# 認証は APP_STORE_CONNECT_API_KEY_* 環境変数（release.yml と同じ）。
require 'spaceship'
require 'json'
require 'net/http'

APP_ID = ARGV[0] or abort 'usage: setup_game_center.rb <asc-app-id>'

token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_KEY_ID'),
  issuer_id: ENV.fetch('APP_STORE_CONNECT_API_KEY_ISSUER_ID'),
  key: Base64.decode64(ENV.fetch('APP_STORE_CONNECT_API_KEY_KEY'))
)

BASE = 'https://api.appstoreconnect.apple.com'

def request(token, method, path, body = nil)
  uri = URI("#{BASE}#{path}")
  klass = { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method)
  req = klass.new(uri)
  req['Authorization'] = "Bearer #{token.text}"
  req['Content-Type'] = 'application/json'
  req.body = JSON.dump(body) if body
  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  [res.code.to_i, res.body.empty? ? {} : JSON.parse(res.body)]
end

# 1. gameCenterDetail（なければ作成）
code, data = request(token, :get, "/v1/apps/#{APP_ID}/gameCenterDetail")
if code == 200 && data['data']
  detail_id = data.dig('data', 'id')
  puts "gameCenterDetail: exists (#{detail_id})"
else
  code, data = request(token, :post, '/v1/gameCenterDetails', {
    data: {
      type: 'gameCenterDetails',
      relationships: { app: { data: { type: 'apps', id: APP_ID } } }
    }
  })
  abort "failed to create gameCenterDetail: #{code} #{data}" unless code == 201
  detail_id = data.dig('data', 'id')
  puts "gameCenterDetail: created (#{detail_id})"
end

LEADERBOARDS = [
  {
    vendor: 'io.ngs.Koikoi.wins',
    reference: 'Wins',
    ja: '勝利数', en: 'Wins',
    ja_fmt: '勝', en_fmt: 'wins'
  },
  {
    vendor: 'io.ngs.Koikoi.totalpoints',
    reference: 'Best Score',
    ja: '最高文数', en: 'Best Score',
    ja_fmt: '文', en_fmt: 'pts'
  }
].freeze

LEADERBOARDS.each do |lb|
  code, data = request(token, :post, '/v1/gameCenterLeaderboards', {
    data: {
      type: 'gameCenterLeaderboards',
      attributes: {
        defaultFormatter: 'INTEGER',
        referenceName: lb[:reference],
        vendorIdentifier: lb[:vendor],
        submissionType: 'BEST_SCORE',
        scoreSortType: 'DESC'
      },
      relationships: {
        gameCenterDetail: { data: { type: 'gameCenterDetails', id: detail_id } }
      }
    }
  })
  if code == 409 && data.to_s.include?('vendorIdentifier')
    puts "leaderboard #{lb[:vendor]}: already exists"
    next
  end
  abort "failed to create #{lb[:vendor]}: #{code} #{data}" unless code == 201
  lb_id = data.dig('data', 'id')
  puts "leaderboard #{lb[:vendor]}: created (#{lb_id})"

  { 'ja' => lb[:ja], 'en-US' => lb[:en] }.each do |locale, name|
    code, data = request(token, :post, '/v1/gameCenterLeaderboardLocalizations', {
      data: {
        type: 'gameCenterLeaderboardLocalizations',
        attributes: { locale: locale, name: name },
        relationships: {
          gameCenterLeaderboard: { data: { type: 'gameCenterLeaderboards', id: lb_id } }
        }
      }
    })
    puts "  localization #{locale}: #{code == 201 ? 'ok' : "failed #{code} #{data}"}"
  end
end

puts 'done'
