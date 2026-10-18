FROM ruby:3.4.11-slim

RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV RAILS_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_WITHOUT=development:test
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
RUN useradd --create-home --shell /bin/bash rails && mkdir -p tmp/pids && chown -R rails:rails /app
USER rails
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
