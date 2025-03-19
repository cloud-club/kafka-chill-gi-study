# 2주차

범위: 4장 + 인프런 강의(컨슈머 파트)

## 목차

### Ch4. Kafka Consumer : 카프카에서 데이터 읽기

- [🌳 Consumer와 Consumer Group](#-consumer와-consumer-group)
- [🌳 Consumer Group과 Partition Rebalance](#-consumer-group과-partition-rebalance)
- [🌳 정적 그룹 멤버십](#-정적-그룹-멤버십)
- [🌳 폴링 루프](#-폴링-루프)
- [🌳 쓰레드 안정성](#-쓰레드-안정성)
- [🌳 컨슈머 설정하기](#-컨슈머-설정하기)
- [🌳 오프셋과 커밋](#-오프셋과-커밋)
- [🌳 리밸런스 리스너](#-리밸런스-리스너)

### 카프카 완벽 가이드 - 코어편

- [🍅 Consumer Group과 Consumer](#-consumer-group과-consumer)
- [🍅 Consumer Group과 Consumer Rebalancing 실습](#-consumer-group과-consumer-rebalancing-실습)
- [🍅 kafka-consumer-groups 명령어](#-kafka-consumer-groups-명령어)
- [🍅 kafka-consumer-groups 명령어로 Consumer Group 삭제하기](#-kafka-consumer-groups-명령어로-consumer-group-삭제하기)

# Ch4. Kafka Consumer : 카프카에서 데이터 읽기

애플리케이션이 Kafka에서 데이터를 읽으려면 Kafka Consumer를 사용하여 카프카 토픽을 구독하고, 이러한 토픽에서 메시지를 수신한다.

## 🌳 Consumer와 Consumer Group

### 🌿 What is Kafka Consumer?

- Consumer는 Kafka Topic의 데이터를 읽고 처리하는 역할을 함.
- Message가 빠르게 쌓이면 처리 속도를 따라가지 못해 지연이 발생할 수 있음
- 여러 Consumer를 활용하면 데이터를 병렬로 처리하여 성능을 향상 시킬 수 있음

### 🌿 Consumer Group

- Consumer Group은 병렬 처리를 위해 Consumer를 그룹화한 단위
- 동일 그룹 내 Consumer는 각기 다른 Partition 데이터를 처리
- Partition 수보다 많은 Consumer는 유휴 상태로 전환된다.

### 🌿 Scale out과 확장성

- 컨슈머 그룹에 컨슈머를 추가하면, 병렬 처리가 가능하여 데이터 처리 속도를 높일 수 있음
- 컨슈머 수가 파티션 수를 초과하면 초과된 컨슈머는 유휴 상태가 됨
- 새로운 컨슈머 그룹을 생성하면 독립적으로 토픽의 모든 메시지를 처음부터 소비할 수 있음

## 🌳 Consumer Group과 Partition Rebalance

### 🌿 What is Rebalance?

- Rebalancing은 그룹 내 파티션 소유권을 재분배하는 과정
- 새로운 컨슈머가 추가되거나 기존 컨슈머가 종료/크래시되면 발생
- 컨슈머는 카프카 브로커의 그룹 코디네이터와 하트비트를 주고받으며 상태를 유지
- 하트비트가 없으면 세션 타임아웃이 발생하며, 그룹 코디네이터는 해당 컨슈머를 제거하고 리밸런스를 실행함

### 🌿 Rebalancing의 목적

- 확장성 보장: Consumer 그룹에 새로운 Consumer가 추가되거나 기존 Consumer가 제거될 때 파티션 할당을 자동으로 조정
- 고가용성 유지 : Consumer가 실패하거나 네트워크 문제가 발생했을 때 해당 Consumer가 처리하던 파티션을 다른 정상 Consumer에게 재할당하여 데이터 처리가 중단되지 않도록 함
- 로드 밸런싱 : 모든 Consumer가 비슷한 양의 데이터를 처리하도록 파티션을 균등하게 분배한다.
- 자동 복구 : 시스템 변경이나 장애 상황에서 Consumer 그룹이 자동으로 복구될 수 있도록 한다.

### 🌿 Rebalancing이 발생하는 상황

Kafka Consumer는 topic 간 Partition에서 메시지를 처리하는 역할을 한다. 그런데 특정 컨슈머가 문제를 겪게 되면 그 consumer가 처리하던 partition의 소유권을 다른 consumer로 넘겨야 한다. 이러한 ‘리밸런싱’ 과정은 주로 아래 4가지 상황에서 발생한다.

- 컨슈머 그룹에 새로운 컨슈머가 추가될 떄
- 기존 컨슈머가 그룹에서 나갈 때
- 구독하는 토픽에 새로운 파티션이 생길 때
- 컨슈머가 구독하는 토픽이 변경될 때

> 일반적으로 리밸런싱이 가장 많이 일어나는 상황은 애플리케이션 배포 시이다. 기존 애플리케이션 종료 후 새로운 애플리케이션이 실행디면서, 기존 컨슈머가 삭제되고 새로운 컨슈머가 생성되기 때문이다.

### 🌿 파티션 할당 전략

Partition Assignment Strategy(파티션 할당 전략)은, 카프카 컨슈머가 토픽의 어떤 파티션을 소비(컨슈밍)할 것인지 결정하는 방식을 의미한다. 이 전략에 따라 컨슈머와 파티션 간의 관계가 결정되며, 데이터 처리 효율성과 성능에 큰 영향을 미친다. 카프카의 파티션 할당 전략은 크게 '적극적 리밸런싱'과 '협력적 리밸런싱'으로 나뉘며, 이에 따라 아래의 4가지의 파티션 할당 전략이 존재한다.  

- 레인지(Range) 파티션 할당 전략
- 라운드 로빈(RoundRobin) 파티션 할당 전략
- 스티키(Sticky) 파티션 할당 전략
- 협력적 스티키(CooperativeSticky) 파티션 할당 전략

### 🌿  **적극적 리밸런스 (Eager Rebalance)**

- 레인지, 라운드 로빈, 스티키 파티션 할당 전략이 해당하는 방식
- 모든 컨슈머가 기존 파티션을 해제하고, 작업이 중단된 후 재할당
  - 모든 컨슈머가 동시에 작업을 멈추는 ‘stop the world’ 현상이 일어나게 되며, 이로 인해 전체 컨슈머 그룹의 데이터 처리가 일시적으로 중단
  - producer의 경우, 리밸런싱과 무관하게 파티션에 데이터를 계속에서 쓰기 때문에 대기 시간 동안 LAG가 급격하게 증가하게 됨
- 작업 중단으로 인해 성능에 부정적 영향을 미칠 수 있음

### 🌿  **협력적 리밸런스 (Cooperative Rebalance)**

- 협력적 스티키 파티션 할당 전략이 해당하는 방식
- 기존 작업을 방해하지 않고, 점진적으로 파티션을 다른 컨슈머에 재할당
- 작업 중단을 방지하며, 효율적으로 파티션을 재분배
- 리밸런싱과 직접적인 관련이 없는 다른 카프카 컨슈머들이 데이터 처리를 계속 진행할 수 잇게 하여, 전체 그룹의 처리 성능에 미치는 영향을 최소화
- 카프카 3.1 이상부터 기본값으로 설정됨

## 🌳 정적 그룹 멤버십

- 기본적으로 컨슈머는 일시적 멤버로, 그룹을 떠나면 기존 파티션이 해제 됨
- [`group.instance.id`](http://group.instance.id) 를 설정하면 정적 그룹 멤버십이 활성화되어, 종료 후에도 동일한 파티션을 유지함

### 🌿 특징

- 종료 후 재참여해도 동일한 파티션을 재할당받아 리밸런스를 방지
- 동일한 [`group.instance.id`](http://group.instance.id) 를 가진 컨슈머가 중복 조인하면 에러가 발생
- 종료 시 컨슈머 그룹을 떠나지 않으며, [`session.timeout.ms`](http://session.timeout.ms) 설정에 따라 멤버심이 해제됨

### 🌿 활용 사례

- 로컬 상태 또는 캐시를 유지해야 하는 애플리케이션에 적합
- 불필요한 리밸런스를 줄여 안정적인 파티션 관리를 지원

## 🌳 폴링 루프

폴링 루프는 컨슈머가 카프카 브로커로부터 데이터를 주기적으로 확인하고 가져오는 메커니즘이다.

### 🌿 작동 방식

- 컨슈머는 `poll()` 메서드를 통해 데이터를 요청한다.
- 데이터가 없다면 설정된 시간 만큼 대기한다.
- 새 데이터가 도착하면 가져와서 처리한다.

### 🌿 첫 번째 poll() 호출의 중요성

- 그룹 코디네이터와 통신을 시작하며 컨슈머 그룹에 가입하는 시점

  > 그룹코디네이터(Group Coorinator) : Consumer Group의 관리를 담당하는 특수한 브로커

- 파티션 할당 및 리밸런스 처리 수행

### 🌿 주의점

- **폴링을 중단하면 컨슈머가 실패한 것으로 간주**되어 리밸런스가 발생
- 정기적으로 `poll()` 을 호출해야 “살아있다”고 인식됨

## 🌳 쓰레드 안정성

### 🌿 핵심 원칙

- “**하나의 쓰레드당 하나의 컨슈머**” 원칙을 반드시 지켜야 함
- 하나의 컨슈머를 여러 쓰레드에서 동시에 사용하면 안됨

### 🌿 문제점

- 여러 쓰레드에서 하나의 컨슈머를 공유하면 데이터 충돌 발생
- 오프셋 관리가 불가능해짐
- 예측 불가능한 동작 발생

### 🌿 효율적인 설계 방법

- 데이터를 가져오는 컨슈머와, 처리하는 워커 쓰레드를 분리
- 컨슈머는 데이터만 가져오고, 별도의 워커 쓰레드가 처리하는 구조
- 멀티 쓰레드 처리가 필요하면 각 쓰레드마다 독립적인 컨슈머 인스턴스 생성

## 🌳 컨슈머 설정하기

### 🌿 **데이터 처리 관련 설정**

- `fetch.min.bytes` : 브로커에서 읽어올 최소 데이터 크기 지정
- `fetch.max.wait.ms` : 데이터가 쌓일 때까지 대기 시간 지정
- `fetch.max.bytes` : 한 번에 가져올 최대 데이터 크기 지정
- `max.poll.records` : 한 번에 가져올 최대 메시지 개수
- `max.partition.fetch.bytes` : 파티션별 반환할 최대 데이터 크기

### 🌿 **타임아웃 및 하트비트 설정**

- `session.timeout.ms` : 하트비트 없이 컨슈머를 살아있다고 간주할 최대 시간 (기본 10초)
- `heartbeat.interval.ms`: 하트비트 전송 간격 (일반적으로 `session.timeout.ms`의 1/3)
- `max.poll.interval.ms` : 폴링 간 최대 대기 시간 (기본 5분)
- `default.api.timeout.ms` : 모든 API 호출에 적용되는 기본 타임아웃
- `request.timeout.ms` : 브로커 응답 대기 최대 시간 (기본 30초)

### 🌿 **오프셋 및 커밋 설정**

- `auto.offset.reset` : 메시지를 읽기 시작할 위치 지정
  - `earliest` : 처음부터 읽음
  - `latest` : 최신 메시지부터 읽음
- `enable.auto.commit` : 오프셋 자동 커밋 여부 설정

### 🌿 **파티션 할당 전략**

- `Range` : 컨슈머 그룹 내에서 연속된 파티션을 하나의 컨슈머에 할당하는 전략
- `RoundRobin` : 파티션을 컨슈머 그룹 내의 모든 컨슈머에게 고르게 분배하는 전략
- `Sticky` : 파티션을 균등하게 분배하며, 리밸런스 시 파티션 이동을 최소화하는 전략
- `Cooperative Sticky` : Sticky에 협력적 리밸런스를 추가해 점진적인 파티션 재할당을 지원하는 전략

### 🌿  **기타 설정**

- `client.id`: 로깅/모니터링용 클라이언트 식별 ID
- `client.rack`: 레플리카를 가져올 데이터센터/클라우드 영역 지정
- `group.instance.id`: 정적 그룹 멤버십 활성화로 리밸런스 최소화
- `receive.buffer.bytes`**,** `send.buffer.bytes`: TCP 송수신 버퍼 크기 설정 (`1`은 OS 기본값 사용)

## 🌳 **오프셋과 커밋**

### 🌿  What is Offset Commit?

- 오프셋 : Kafka 파티션 내 각 메시지의 위치 번호
- 오프셋 커밋은 컨슈머가 읽은 메시지의 위치를 저장하는 작업
- 카프카는 메시지를 개별적으로 커밋하지 않고, `__consumer__offsets` 라는 내부 토픽에 저장
- 커밋되지 않은 오프셋은 동일 메시지의 중복 소비 가능성을 초래

### 🌿 Offset Commit의 중요성

- 컨슈머가 재시작될 때 어디서부터 읽어야 할지 알 수 있음
- 커밋하지 않으면 같은 메시지를 중복해서 처리할 위험이 있음

### 🌿 **자동 커밋**

- 가장 간단한 방법으로, kafka가 자동으로 오프셋을 저장
- `enable.auto.commit=true` 설정 시 컨슈머가 오프셋을 자동으로 커밋
- 설정된 주기(`auto.commit.interval.ms`, 기본값 5초)마다 커밋 수행
- 장점
  - 개발자가 직접 오프셋을 관리할 필요 없음
  - 구현이 매우 간단함
- **단점**
  - 컨슈머가 갑자기 중단되면, 처리는 했지만 아직 커밋되지 않은 메시지를 다시 처리하게 됨 (크래시 발생 시, 처리된 메시지와 커밋된 오프셋 간 차이로 중복 소비 발생 가능)

### 🌿 **수동 커밋**

- 더 세밀한 제어가 필요할 때 사용하는 방법
- `enable.auto.commit=false` 설정 시 수동으로 오프셋 커밋 가능
- **커밋 방법**
  - `commitSync()`: 동기적 커밋
    - 커밋이 성공했는지 확실히 알 수 있음
    - 커밋이 완료될 때까지 애플리케이션이 일시 중지됨
  - `commitAsync()`: 비동기적 커밋
    - 애플리케이션이 블록되지 않아 처리량이 높음
    - 실패해도 자동으로 재시도하지 않음
    - 콜백을 통해 결과 확인 가능
- **단점**
  - 동기 커밋은 처리량을 제한할 수 있음
  - 비동기 커밋은 커밋 실패를 감지하기 어려움

### 🌿 **동기적/비동기적 커밋 병행**

- 가장 균형 잡힌 접근법
  - 일반 작업은 비동기 커밋으로 빠르게 처리
  - 중요한 순간(종료, 예외 발생)에는 동기 커밋으로 안전하게 처리
- 컨슈머 종료 시 또는 리밸런스 직전에는 `commitSync()`를 사용해 안정적으로 오프셋을 커밋함
- 일반 상황에서는 `commitAsync()`를 사용해 성능을 최적화함
- 병행 사용으로 데이터 정확성과 성능을 모두 보장

## 🌳 리밸런스 리스너

리밸런스 리스너는 Kafka 컨슈머 그룹에서 파티션 재분배(리밸런싱)가 일어날 때 컨슈머가 정리 작업(Cleanup)을 수행하도록 지원하는 메커니즘이다.

### 🌿 필요성

리밸런싱이 갑자기 발생하면 다음과 같은 문제가 생길 수 있다.

- 아직 커밋하지 않은 메시지의 오프셋 정보가 사라질 수 있음
- 열려있는 파일이나 데이터베이스 연결이 제대로 닫히지 않을 수 있음
- 진행 중이던 작업이 중단될 수 있음

리밸런스 리스너는 이런 상황에서 “정리 작업(Cleanup)”을 수행할 기회를 제공한다.

### 🌿 주요 역할

리밸런스 리스너는 다음과 같은 2가지 중요한 시점에 작동한다.

1. 파티션을 잃기 전(onPartitionsRevoked)
   - 현재 처리 중인 작업을 마무리
   - 마지막으로 처리한 오프셋을 커밋
   - 열려있는 리소스(파일, DB 연결 등)를 정리
2. 새 파티션을 받은 후(onPartitionsAssigned)
   - 새로 할당받은 파티션 작업을 위한 초기화
   - 필요한 리소스 준비
   - 특별한 설정이나 상태 복구

# 카프카 완벽 가이드 - 코어편

> 🔗 [https://www.inflearn.com/course/카프카-완벽가이드-코어?srsltid=AfmBOoqevFk6v7QNyxpS8gOYwIryzN68uyOuMqNrVJtxpeK4JDdlmiIX](https://www.inflearn.com/course/%EC%B9%B4%ED%94%84%EC%B9%B4-%EC%99%84%EB%B2%BD%EA%B0%80%EC%9D%B4%EB%93%9C-%EC%BD%94%EC%96%B4?srsltid=AfmBOoqevFk6v7QNyxpS8gOYwIryzN68uyOuMqNrVJtxpeK4JDdlmiIX)

## 🍅 Consumer Group과 Consumer

**모든 Consumer들은 단 하나의 Consumer Group에 소속**되어야 하며, Consumer Group은 1개 이상의 Consumer를 가질 수 있다. **Partition 레코드들은 단 하나의 Consumer에만 할당**된다. 

> 💡 일반적으로는 Partition의 개수와 Consumer의 개수를 맞춰준다. 
> → Partition 별로 병렬도가 증가하기 때문이다.

> Consumer Group 내에 1개의 Consumer만 있을 경우

![image](https://github.com/user-attachments/assets/8d69e5b6-a830-4866-84e0-37770bf5c5a5)

> Consumer Group 내에 2개의 Consumer가 있지만 토픽 파티션 개수보다 작을 경우

- Consumer Group 내에서는 Consumer들 끼리, Partition들에 대한 병렬 분산을 수행한다.
- Rabalancing : Consumer Group 내에 Consumer 변화가 있을 시마다 파티션과 Consumer의 조합을 변경
  - 새로운 Consumer가 그룹에 참여할 때
  - 기존 Consumer가 그룹을 떠날 때
  - 토픽의 파티션 수가 변경될 때
 
![image](https://github.com/user-attachments/assets/e4acf86c-df85-4c8f-b489-a4cf2412c66d)

> Consumer Group 내에 파티션 개수와 동일한 Consumer가 있을 경우

- Partition 개수로 Consumer를 맞춰놓는게 가장 좋은 결합이다.

![image](https://github.com/user-attachments/assets/9141b7d0-127d-499f-bc2b-19b5d13f2078)

> Consumer Group 내에 파티션 개수보다 많은 Consumer가 있을 경우

- 하나의 Producer는 단 하나의 Consumer와만 연결되기 때문에, 다음과 같이 Consumer > Producer 인 경우, 놀고있는 Consumer가 생긴다.

![image](https://github.com/user-attachments/assets/e01d4577-13bb-45d2-a723-ebeba529f392)

### Consumer group.id

모든 Consumer들은 고유한 그룹 아이디 `group.id` 를 가지는 Consumer Group에 소속되어야 한다. 개별 Consumer Group 내에서 여러 개의 Consumer들은 토픽 파티션 별로 분배된다.

- **동일**한 Consumer Group 내의 Consumer들은 작업량을 **최대한 균등하게 분배**
- **서로 다른** Consumer Group의 Consumer들은 분리되어 **독립적으로 동작**

> 하나의 토픽을 여러개의 Consumer Group이 Subscribe 할 경우

![image](https://github.com/user-attachments/assets/3aa8c0c4-11bc-43d1-9410-8c6ff73ed6d6)

![image](https://github.com/user-attachments/assets/c1efd092-78d8-4baf-b067-d7ea810780b8)

## 🍅 Consumer Group과 Consumer Rebalancing 실습

다음과 같이 partition을 3개가지는 `multipart-topic` 토픽에 consumer 그룹 `group_01` 을 생성해보자.

```bash
kafka-console-consumer --bootstrap-server localhost:9092 --group group_01 --topic multipart-topic --property print.key=true --property print.value=true --property pring.partition=true
```

그리고 다음과 같이 Consumer Grop id `group_01` 을 가지는 consumer를 3개 생성하자. (아래 명령어 3번 수행)

```bash
kafka-console-consumer --bootstrap-server localhost:9092 --group group_01 --topic multipart-topic --property print.key=true --property print.value=true --property print.partition=true
```

그러면 명령어를 한 번 수행할 때마다 , consumer 그룹에 consumer가 추가되고, 그때마다 Rebalancing이 이루어진다. 또한 consumer가 제거될 때마다(LeaveGroup) Rebalancing이 진행된다.

![image](https://github.com/user-attachments/assets/cf230e37-3313-4376-8ae7-48383bd173e2)


## 🍅 kafka-consumer-groups 명령어

`kafka-consumer-groups` 는 굉장히 활용도가 높은 명령어이다. 

- Consumer Group list 정보
- Consumer Group과 Consumer 관계, Partition 등에 대한 상세 정보
- Consumer Group 삭제
- Producer가 전송한 Log message의 지연 Lag 정보

---

현재 만들어져있는 group id 확인 (Consumer는 3개)

```bash
$ kafka-consumer-groups --bootstrap-server localhost:9092 --list
group_01
```

`kafka-consumer-groups` 커맨드를 `--describe` 옵션과 함께 사용하면 다음과 같이 그룹 상세 정보를 확인할 수 있다. 

- `GROUP`
- `TOPIC`
- `PARTITION`
- `CURRENT-OFFSET` : consumer가 가장 최근에 읽은 메시지의 offset
- `LOG-END-OFFSET` : producer가 topic에 가장 최근에 쓴 메시지의 offset
- `LAG` : 아직 처리되지 않은 메시지의 수, LAG가 계속 증가한다면 consumer가 메시지를 처리하는 속도가 너무 느리다는 신호일 수 있으며 이는 시스템 성능 문제나 병목 현상을 나타낼 수 있다.
- `CONSUMER-ID`

현재는 보낸 메시지가 없고, LAG가 0인 상태이다.

```bash
$ kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group group_01

GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID
                                  HOST            CLIENT-ID
group_01        multipart-topic 2          0               0               0               console-consumer-bf7c104c-0ed1-4294-98ab-76f16e7654d2 /127.0.0.1      console-consumer
group_01        multipart-topic 0          0               0               0               console-consumer-576517fc-b2d0-4c4c-a7e4-24c11d070b7d /127.0.0.1      console-consumer
group_01        multipart-topic 1          0               0               0               console-consumer-aa5bbef8-bcc9-4d79-bfd5-e873ca0a284f /127.0.0.1      console-consumer
```

consumer를 consumer그룹에서 모두 빼고(그룹은 유지) 메시지를 보내봐보자.

`Consumer group 'group_01' has no active members.` 이렇게 확인할 수 있다.

```bash
kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group group_01

Consumer group 'group_01' has no active members.

GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
group_01        multipart-topic 0          0               0               0               -               -   
            -
group_01        multipart-topic 1          0               0               0               -               -   
            -
group_01        multipart-topic 2          0               0               0               -               -   
            -
```

key를 가지는 메시지를 전송해보자.

```bash
$ kafka-console-producer --bootstrap-server localhost:9092 --topic multipart-topic \
> --property key.separator=: --property parse.key=true
>1:aaa
>2:bbb
>
```

이 상태로 위 명령어를 통해 메시지를 2개 보내면, 현재 consumer 그룹에 consumer가 없기 때문에, `LAG` 가 2개 쌓인 것을 확인할 수 있다. 

```bash
$ kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group group_01

Consumer group 'group_01' has no active members.

GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
group_01        multipart-topic 0          0               1               1               -               -   
            -
group_01        multipart-topic 1          0               0               0               -               -   
            -
group_01        multipart-topic 2          0               1               1               -               -   
            -
```

더 보내보면, 계속 쌓이고 있다.

```bash
$ kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group group_01

Consumer group 'group_01' has no active members.

GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
group_01        multipart-topic 0          0               1               1               -               -   
            -
group_01        multipart-topic 1          0               1               1               -               -   
            -
group_01        multipart-topic 2          0               2               2               -               -   
            -
```

메시지를 2000개 정도 보내봐보자.

```bash
$ touch load.log
vboxuser@ubuntu:~$ for i in {1..2000}
> do
> echo "test nonkey message sent test00000000000000 $i" >> load.log
> done
$ kafka-console-producer --bootstrap-server localhost:9092 --topic multipart-topic < load.log
$ kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group group_01

Consumer group 'group_01' has no active members.

GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
group_01        multipart-topic 0          0               818             818             -               -   
            -
group_01        multipart-topic 1          0               588             588             -               -   
            -
group_01        multipart-topic 2          0               598             598             -               -   
            -
```

그리고 consumer를 하나 띄워보자.

```bash
$ kafka-console-consumer --bootstrap-server localhost:9092 --group group_01 --topic multipart-topic \
--property print.key=true --property print.value=true \
--property print.partition=true

Partition:0     null    test nonkey message sent test00000000000000 1275
Partition:0     null    test nonkey message sent test00000000000000 1276
Partition:0     null    test nonkey message sent test00000000000000 1277
Partition:0     null    test nonkey message sent test00000000000000 1278
Partition:0     null    test nonkey message sent test00000000000000 1279
Partition:0     null    test nonkey message sent test00000000000000 1280
Partition:0     null    test nonkey message sent test00000000000000 1281
Partition:0     null    test nonkey message sent test00000000000000 1282
Partition:0     null    test nonkey message sent test00000000000000 1283
Partition:0     null    test nonkey message sent test00000000000000 1284
Partition:0     null    test nonkey message sent test00000000000000 1285
Partition:0     null    test nonkey message sent test00000000000000 1286
Partition:0     null    test nonkey message sent test00000000000000 1287
Partition:0     null    test nonkey message sent test00000000000000 1288
Partition:0     null    test nonkey message sent te
.....
```

그러면 message 들이 컨슈밍되고, 다시 그룹 상세정보를 확인해보면 `LAG` 가 없어지고, `CURRENT-OFFSET` 이 늘어난 것을 확인할 수 있다. 

```bash
$ kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group group_01

Consumer group 'group_01' has no active members.

GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
group_01        multipart-topic 0          818             818             0               -               -   
            -
group_01        multipart-topic 1          588             588             0               -               -   
            -
group_01        multipart-topic 2          598             598             0               -               -   
            -
```

## 🍅 kafka-consumer-groups 명령어로 Consumer Group 삭제하기

Consumer Groups는 자동 삭제되지 않는다. 그룹 안의 모든 Consumer가 모두 삭제되더라도, 그룹은 삭제되지 않고 일정 기간 동안 보관된다. 일정 기간 보관되다가, 더 이상 소속된 consumer가 없으면 그때 삭제된다.

이때, 바로 Consumer Group을 삭제하기 위해 사용할 수 있는 명령어가 `kafka-consumer-groups` 이다. 이 명령어는 다음과 같이 Consumer Group에 Consumer가 아무것도 없을 때 사용할 수 있다.

```bash
$ kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group group_01

Consumer group 'group_01' has no active members.

GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
group_01        multipart-tpic  0          0               0               0               -               -   
            -
group_01        multipart-topic 0          818             818             0               -               -   
            -
group_01        multipart-topic 1          588             588             0               -               -   
            -
group_01        multipart-topic 2          598             598             0               -               -   
            -
```

삭제는 `--delete` 옵션으로 수행할 수 있다.

```bash
# 그룹 리스트 확인
$ kafka-consumer-groups --bootstrap-server localhost:9092 --list
group_01

# 그룹 삭제
$ kafka-consumer-groups --bootstrap-server localhost:9092 --delete --group group_01
Deletion of requested consumer groups ('group_01') was successful.

# 그룹 삭제 확인
$ kafka-consumer-groups --bootstrap-server localhost:9092 --list
```
