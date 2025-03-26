(notion 정리중 ... 이어 작성 예정 ..)

## Managing Apache Kafka Programmatically

Kafka 관리를 위해 많은 CLI, GUI 도구가 존재하지만, 클라이언트 애플리케이션 내에서 일부 관리 명령을 실행해야 할 경우도 있다.

사용자 입력이나 데이터를 기반으로 새로운 Topic을 즉석에서 생성하는 경우가 많으며, IoT 애플리케이션은 종종 사용자 장치로부터 이벤트를 수신하고 장치 유형에 따라 이벤트를 Topic에 기록한다.

제조업체가 새로운 장치를 생산하는 경우, Topic을 생성하는 절차는 다음 두 가지 방법 중 하나다:

- 절차를 기억하고 수동으로 생성
- 애플리케이션이 이벤트 수신 시 동적으로 생성

두 번째 방식은 단점도 있지만, 별도 프로세스 없이 Topic을 생성할 수 있다는 점에서 매력적이다.

Kafka는 **버전 0.11**부터 `AdminClient`를 도입하여, CLI에서 수행하던 관리 기능을 위한 **프로그래밍 API**를 제공한다.

- Topic 나열, 생성, 삭제
- 클러스터 설명
- ACL(접근 제어), 구성 수정 등

예를 들어, 어떤 애플리케이션이 8개의 특정 Topic에 이벤트를 생산해야 한다면, 첫 이벤트를 보내기 전에 해당 Topic이 존재해야 한다.

과거에는 `producer.send()`에서 `UNKNOWN_TOPIC_OR_PARTITION` 예외를 감지해 사용자가 Topic을 생성해야 했지만, AdminClient 덕분에 이제는 애플리케이션 내에서 직접 관리가 가능하다.

이 문서에서는 AdminClient의 개요와 함께 Topic 관리, Consumer group, 구성 작업을 중심으로 살펴본다.

---

## AdminClient Overview

### Asynchronous and Eventually Consistent API

Kafka의 AdminClient는 **비동기적으로 동작**한다. 메서드는 요청을 클러스터 컨트롤러에 전달한 후 즉시 반환하며, 하나 이상의 `Future` 객체를 반환한다.

- `Future` 객체는 비동기 작업 결과로, 상태 확인, 대기, 완료 후 콜백 실행 가능
- Kafka는 이를 `Result` 객체로 감싸 후속 작업을 도와준다

예: `createTopics()`는 `CreateTopicsResult` 객체를 반환하며, 생성된 Topic들의 상태를 개별적으로 확인 가능하다.

Kafka의 메타데이터 전파는 **비동기적**이므로, `ListTopics`는 최신 상태를 보장하지 않는다 → **최종 일관성(Eventual Consistency)**

---

### Options

각 메서드는 특정 Options 객체를 받는다.

- `listTopics` → `ListTopicsOptions`
- `describeCluster` → `DescribeClusterOptions`

공통 옵션:

- `timeoutMs`: 클러스터 응답 대기 최대 시간 → 초과 시 `TimeoutException`
- `includeInternal`: 내부 Topic 포함 여부 설정 가능

---

### Flat Hierarchy

모든 관리 작업은 `KafkaAdminClient`에 직접 구현되어 있음. 계층 구조 없이 하나의 JavaDoc만 보면 모든 기능 확인 가능.

---

### Additional Notes

- 대부분의 관리 작업은 `AdminClient`로 수행, **Zookeeper 직접 사용은 권장되지 않음**
- Zookeeper 의존성 제거 예정 → `AdminClient` 사용 권장

---

## AdminClient Lifecycle: Creating, Configuring, and Closing

```java
Properties props = new Properties();
props.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
AdminClient admin = AdminClient.create(props);
// TODO: AdminClient로 유용한 작업 수행
admin.close(Duration.ofSeconds(30));
```

- `create()`는 클러스터 URI 목록 필수 (운영 환경에선 최소 3개 브로커 지정 권장)
- `close()`는 타임아웃을 설정 가능 → 타임아웃 없으면 모든 작업이 끝날 때까지 대기

---

### 중요 설정

- **client.dns.lookup** (Kafka 2.1.0 도입)
  - DNS 별칭, 여러 IP 주소 지원
  - `client.dns.lookup=use_all_dns_ips` → 첫 IP 실패 시 다른 IP 자동 시도 가능

- **request.timeout.ms**
  - 재시도 시간 포함, 응답 최대 대기 시간 제한

---

## Essential Topic Management

### 1. Topic 나열

```java
ListTopicsResult topics = admin.listTopics();
topics.names().get().forEach(System.out::println);
```

### 2. Topic 존재 여부 확인

`describeTopics()`로 특정 Topic 설명 요청 → 존재하지 않으면 예외 처리 필요

### 3. Topic 생성

```java
CreateTopicsResult newTopic = admin.createTopics(Collections.singletonList(
    new NewTopic(TOPIC_NAME, NUM_PARTITIONS, REP_FACTOR)
));
```

### 4. Topic 생성 확인

```java
if (newTopic.numPartitions(TOPIC_NAME).get() != NUM_PARTITIONS) {
    System.out.println("토픽의 파티션 수가 잘못되었습니다.");
    System.exit(-1);
}
```

### 5. 오류 처리

AdminClient 작업 실패 시 `ExecutionException` 발생 → 원인 파악 필요

### 6. Future 객체

모든 AdminClient 메서드는 결과를 `Future` 객체로 래핑 → `get()` 사용하여 결과 확인 및 예외 처리

---

Kafka의 `AdminClient`를 통해 애플리케이션 내에서 토픽을 유연하게 관리하고, 동적으로 토픽 생성 및 상태 확인이 가능하다. 이를 통해 사용자 경험을 향상시키고 운영 복잡도를 줄일 수 있다.

