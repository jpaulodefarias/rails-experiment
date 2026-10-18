FROM ruby:3.4.11-slim

RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential git libpq-dev postgresql-client && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
COPY Gemfile Gemfile.lock ./
RUN bundle install
CMD ["sleep", "infinity"]
