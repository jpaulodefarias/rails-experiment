class UserEventPublisher
  def initialize
    config = {
      "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092"),
      "enable.idempotence": true,
      acks: "all",
      "message.timeout.ms": 10_000
    }
    @producer = Rdkafka::Config.new(config).producer
    @topic = ENV.fetch("KAFKA_TOPIC", "user.events.v1")
  end

  def publish(event)
    handle = @producer.produce(topic: @topic, payload: event.payload.to_json, key: event.user_id.to_s)
    handle.wait(max_wait_timeout: 15)
  end

  def close
    @producer.close
  end
end
