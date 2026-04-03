FROM ruby:3.3-slim
RUN apt-get update -qq && apt-get install -y build-essential libyaml-dev
WORKDIR /app
COPY Gemfile ./
RUN bundle install
COPY . .
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=eval_secret_key_base_not_for_production
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3000"]
