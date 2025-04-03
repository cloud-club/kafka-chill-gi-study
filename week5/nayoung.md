# 4주차

범위: 6장 + 인프런 강의

## 목차
### Ch6. Kafka 내부 메커니즘
- [클러스터 멤버십](#클러스터-멤버십)
- [컨트롤러](#컨트롤러)
- [KRaft: 카프카의 새로운 Raft 기반 컨트롤러](#kraft-카프카의-새로운-raft-기반-컨트롤러)
- [복제](#복제)
- [요청 처리](#요청-처리)
- [쓰기 요청](#쓰기-요청)
- [읽기 요청 처리](#읽기-요청-처리)
- [물리적 저장소](#물리적-저장소)

### 카프카 완벽 가이드 - 코어편
- [카프카 환경 파라미터 구분 및 kafka-configs 명령어로 파라미터 검색 및 수정 적용하기](#카프카-환경-파라미터-구분-및-kafka-configs-명령어로-파라미터-검색-및-수정-적용하기)
- [kafka-configs 사용하기](#kafka-configs-사용하기)
- [kafka-dump-log 명령어로 로그 파일의 메시지 내용 확인하기](#kafka-dump-log-명령어로-로그-파일의-메시지-내용-확인하기)
- [Java 기반에서 Producer 구현하기](#java-기반에서-producer-구현하기)
- [Producer Java 클라이언트 API 내부를 IntelliJ Debugger를 이용하여 살짝 뜯어보기](#producer-java-클라이언트-api-내부를-intellij-debugger를-이용하여-살짝-뜯어보기)
- [Producer와 Broker 와의 메시지 동기화/비동기화 전송](#producer와-broker-와의-메시지-동기화비동기화-전송)
- [Producer의 메시지 동기화 전송](#producer의-메시지-동기화-전송)
- [Producer의 메시지 비동기화 전송](#producer의-메시지-비동기화-전송)
- [Key 값을 가지는 메시지 전송](#key-값을-가지는-메시지-전송)
- [Acks 값 설정에 따른 Producer의 전송 방식 차이 이해](#acks-값-설정에-따른-producer의-전송-방식-차이-이해)

  
# Ch6. Kafka 내부 메커니즘

애플리케이션이 Kafka에서 데이터를 읽으려면 Kafka Consumer를 사용하여 카프카 토픽을 구독하고, 이러한 토픽에서 메시지를 수신한다.

## 🌳 클러스터 멤버십

### 🌿 브로커 목록 관리

Kafka 클러스터의 브로커 목록은 ZooKeeper에서 관리하며 `/brokers/ids` 경로에 저장된다. 

### 🌿 브로커 ID

- 브로커는 생성 시 고유한 ID를 가짐
- ID는 사용자가 직접 설정하거나, 자동으로 생성 가능

### 🌿 Ephermeral 노드

- Zookeeper는 브로커 ID를  Ephemeral 노드의 형태로 저장(등록)
- 브로커가 삭제되면, 해당 Ephemeral 노드도 자동으로 제거됨

### 🌿 브로커 ID 재활용

- 운영 중인 카프카에서는 모든 브로커 ID가 완전히 제거되지 않음
- 동일한 ID를 새 브로커에 할당하면, 기존 브로커를 대체하여 정상적으로 동작 가능

## 🌳 컨트롤러

### 🌿 컨트롤러의 역할

- 파티션 리더 선출과 같은 핵심 역할 수행
- 클러스터 동작을 종류

### 🌿 컨트롤러 선출 과정

1. 첫 번째 브로커가 ZooKeeper의 `/controller` 경로에 Ephermeral 노드를 생성하며 컨트롤러로 지정
2. 이후에 시작된 다른 브로커들은 노드 생성에 실패하고, `/controller` 의 변경 사항을 감지하기 위해 watch를 설정함
    1. 해당 경로에 생성하려고 시도하지만, ‘노드가 이미 존재함’ 예외를 받게 됨 → 컨트롤러 노드가 이미 존재한다는 것을 감지
3. 이를 통해 클러스터 내에서 항상 하나의 컨트롤러만 유지됨

### 🌿 브로커 장애 처리

- 컨트롤러는 장애가 발생하 브로커를 감지 후, 해당 브로커가 리더로 맡고 있던 모든 파티션을 순회
- 파티션의 레플리카 목록에서 다음 레플리카를 리더로 선출

### 🌿 리더 전환 요청

- 컨트롤러는 LeaderAndISR 요청을 통해 새로운 리더와 팔로워 정보를 업데이트

### 🌿 브로커 추가 시 처리

- 새 브로커가 추가될 경우 리더 선출 없이 모든 파티션 레플리카를 팔로워로 설정

### 🌿 ZooKeeper 기반 컨트롤러의 한계

- 메타데이터 불일치
    - 컨트롤러가 주키퍼에 메타 데이터를 쓰는 작업은 동기적
    - 반면, 업데이트 및 메시지 전달 작업은 비동기적 → 불일치 가능성
- 컨트롤러 재시작 문제
    - 재시작 시 모든 브로커와 파티션 메타데이터를 다시 읽고 전송해야 하므로 시간이 지연됨
- ZooKeeper 학습 부담
    - ZooKeeper는 분산 시스템으로 설계되어 추가 학습이 필요하며, 카프카 학습 곡선을 높이는 원인이 됨

## 🌳 KRaft: 카프카의 새로운 Raft 기반 컨트롤러

### 🌿 로그 기반 아키텍처

- 기존 주키퍼 기반 컨트롤러는 메타데이터를 관리하며 다양한 기능 수행

> Zookeeper는 학교에서 여러 선생님들(Kafka 서버들)이 있고, 이 선생님들이 모두 잘 협력해서 일하려면 교장 선생님(Zookeeper)이 필요한 것과 비슷하다.
> 
- KRaft는 이벤트 로그 기반 설계로 여러 컨트롤러 노드가 메타데이터의 이벤트 로그를 관리

> 교장 선생님(Zookeeper) 없이 선생님들(Kafka 서버들)이 스스로 학교를 운영할 수 있게 된 것이다. 선생님들끼리 투표해서 누가 리더가 될지 정하고, 함께 협력해서 학교를 운영한다.
> 

### 🌿 다중 컨트롤러 구성

- 리더 컨트롤러(액티브 컨트롤러)와 여러 팔로워 컨트롤러로 구성
- 리더 컨트롤러가 장애 시 팔로워 컨트롤러 중 하나를 리더로 승격
- 장애 발생 시에도 빠른 재시작이 가능

### 🌿 Zookeeper와 KRaft 컨트롤러 비교

**ZooKeeper 기반 컨트롤러**

- 브로커 중 하나가 컨트롤러 역할을 수행
- 주키퍼와 함께 파티션 리더 선출 및  메타데이터 관리 담당

**KRaft 컨트롤러**

- 브로커와 별개의 카프카 프로세스로 동작
- 리더 컨트롤러에서 파티션 리더 선출과 메타데이터 관리를 전담
- Raft 기반 설계로 다수의 컨트롤러가 존재하여 고가용성 제공

## 🌳 복제

### 🌿 복제 기능의 중요성

- 카프카는 다수의 레플리카를 통해 신뢰성과 지속성을 보장
- 장애 발생 시에도 데이터 손실 없이 클러스터가 안정적으로 동작하도록 설계됨

### 🌿 리더 레플리카

- 파티션에 대한 모든 읽기 및 쓰기 요청을 처리함

### 🌿 팔로워 레플리카

- 리더 레플리카 데이터를 복제하여 최신 상태를 유지함
- 리더 레플리카가 장애를 겪으면 팔로워 레플리카 중 하나가 리더로 승격됨

### 🌿 팔로워 레플리카의 읽기 요청

- `rack` 설정 값에 다라 팔로워 레플리카도 읽기 요청을 처리할 수 있음
- 장점 : 부하를 분산하고 가까운 레플리카에서 데이터를 읽어와 트래픽 비용 절감
- 단점 : 리더 커밋 상태를 확인해야 하므로 일관성을 유지하는 과정에서 지연 발생 가능

### 🌿 레플리카 상태 확인

- 리더 레플리카는 팔로워 레플리카의 복제 상태를 확인
- 복제 상태에 따라 in-sync 레플리카(ISR)와 out-of-sync 레플리카(OSR)로 분류
    - In-Sync-Replicas(ISR) : High Water Mark(가장 최근에 커밋된 메시지의 오프셋 추적)라고 하는 지점까지 동일한 Replicas(Leader와 Follwer 모두)의 목록 → ISR에 속해있는 구성원만이 리더의 자격을 가짐
    - Out-Sync-Replicas(OSR) : 원본 메시지보다 늦게 복제되는 경우
- 복제 지연 기준은 `replica.lag.time.max.ms` 설정으로 관리됨
    - 읽기 요청을 보내지 않거나 뒤처진 상태로 있을 수 있는 ‘일정 시간’

### 🌿 리더 선출 기준

- 리더 레플리카가 장애를 겪으면 in-sync 레플리카 중에서 새로운 리더를 선출함

### 🌿 선호 리더 레플리카

- 선호 리더(preferred leader) 레플리카는 토픽이 처음 생성되었을 때 리더 레플리카였던 레플리카
- 선호 리더가 in-sync 상태일 경우, 리더로 승격되어 부하 분산 유지가 가능함

## 🌳 요청 처리

### 🌿 브로커와 클라이언트 통신

- 카프카 브로커는 TCP 이진 프로토콜을 사용해 클라이언트와 통신함

### 🌿 내부 요청 처리 로직

![image.png](https://github.com/user-attachments/assets/30b0e916-0c44-4535-a532-94610d2a1495)

- Acceptor 스레드(레스토랑 문 앞의 호스트/호스티스)
    - 브로커는 연결을 받는 포트별로 acceptor 스레드를 실행
    - 요청을 processor 스레드(네트워크 스레드)로 전달
- Processor 스레드(레스토랑 서버)
    - 받은 요청을 요청 큐에 넣음
    - 완료된 응답을 응답 큐에서 받아 클라이언트로 전송
- I/O 스레드(Request Handler) (요리사)
    - 요청 큐에서 요청을 가져와 처리
    - 완료된 요청의 응답을 응답 큐에 추가
- Purgatory (대기 공간)
    - 응답이 지연되는 상황(예: 데이터 준비 중)에서는 요청을 purgatory에 임시 저장
    - 요청 처리가 완료되면 purgatory에서 응답을 꺼내 클라이언트로 전송

### 🌿 메타데이터 요청 처리

> 클라이언트는 어디로 요청을 보내야 하는지 어떻게 알까?
> 
- 클라이언트가 Kafka 클러스터에 대한 정보를 요청하는 작업
- 메타데이터 요청은 클라이언트가 다루고자 하는 토픽들의 목록을 포함하여, 토픽들에 어떤 파티션들이 있고, 각 파티션의 레플리카에서는 무엇이 있으며, 어떤 레플리카가 리더인지를 명시하는 응답을 리턴
- 리더 파티션 정보 요청
    - 클라이언트는 리더 파티션이 있는 브로커로 읽기/쓰기 요청을 전송
    - 이를 위해, 클라이언트는 주기적으로 메타데이터 요청을 아무 브로커로 보냄
    - 반환된 메타데이터를 캐시하여 사용
- 메타데이터에는 각 파티션 리더가 누구인지 등의 데이터를 캐시해놓고, Not a Leader 응답이 올 때 메타데이터 갱신(새로고침)을 하여 메타데이터에 저장된 리더에 요청을 보내는 방식
- 메타데이터 요청 응답
    - 메타데이터에는 토픽, 파티션, 레플리카, 리더 레플리카 정보 포함
    - 리더 변경 시, Not a Leader 에러 발생 → 메타데이터 최신화 후 재요청

![image.png](https://github.com/user-attachments/assets/2834061c-f5c8-48ec-a6df-a24f1ef7a544)

## 🌳 쓰기 요청

- `acks=0` → 요청 즉시 응답
- `acks=1` → 리더 브로커 쓰기 완료 시 응답
- `acks=all` → 모든 레플리카 복제 완료 후 응답

### 🌿 Purgatory 사용

- 리더 브로커는 쓰기 요청 처리 중 레플리카 응답 대기
- 대기 중 응답을 Purgatory에 저장하며, 복제 완료 시 클라이언트로 응답 전송

## 🌳 읽기 요청 처리

### 🌿 클라이언트 요청

- 클라이언트는 읽고자 하는 토픽, 파티션, 오프셋, 데이터 한도 정보를 브로커에 전송

### 🌿 리더 브로커 동작

- 요청 오프셋의 유효성 검사를 수행
- 유효하지 않으면 에러 반환, 유효하면 데이터를 전송

### 🌿 Zero-Copy 최적화

> 
> 
> - **일반 방식**: 디스크 → 메모리 버퍼 → CPU → 네트워크 카드
> - **Zero-Copy 방식**: 디스크 → 바로 네트워크 카드
- 리더 브로커는 데이터를 읽을 때 Zero-Copy 최적화를 사용
- 데이터 중간 버퍼 없이 네트워크 채널로 직접 전송 → 오버헤드 감소

### 🌿 Fetch Session Cache

- 클라이언트가 많은 파티션 데이터를 읽는 경우 변경 사항만 업데이트하여 요청 크기를 최소화
    - 읽고자하는 파티션의 집합이나 여기에 연관된 메타데이터는 여간해서는 잘 바뀌지 않는다
    - 읽고 있는 파티션의 목록과 그 메타데이터를 캐시하는 세션을 생성
- 세션 생성/해제 제한 발생 시 적절한 에러 반환

## 🌳 물리적 저장소

- 카프카의 기본 저장 단위는 파티션 레플리카
- 저장구조 : 로컬 저장소(빠른 처리용)+원격저장소(HDFS,S3)
- 파티션 할당: 브로커에 균등 분산, 서로 다른 브로커와 랙에 레플리카 배치
- 파일 관리 : 세그먼트 단위로 관리, active 세그먼트(현재 쓰여지고, 사용중인 있는 세그먼트)는 삭제되지 않음
    - 각 파티션마다 active 세그먼트가 있음
    - active 세그먼트는 아직 다 채워지지 않았기 때문에 삭제되거나 압착되지 않음
- 보존 정책 : 삭제(기간/크기 기준) 또는 압착(키별 최신 값만 유지)
- 데이터 삭제 : null 값(tombstone) 설정 또는 deleteRecords 메서드 사용
- 압착 조건 : 세그먼트의 50% 이상이 더티 상태(압착 되지 않은 상태)일 때, active 세그먼트 제외

# 카프카 완벽 가이드 - 코어편

> 🔗 [https://www.inflearn.com/course/카프카-완벽가이드-코어?srsltid=AfmBOoqevFk6v7QNyxpS8gOYwIryzN68uyOuMqNrVJtxpeK4JDdlmiIX](https://www.inflearn.com/course/%EC%B9%B4%ED%94%84%EC%B9%B4-%EC%99%84%EB%B2%BD%EA%B0%80%EC%9D%B4%EB%93%9C-%EC%BD%94%EC%96%B4?srsltid=AfmBOoqevFk6v7QNyxpS8gOYwIryzN68uyOuMqNrVJtxpeK4JDdlmiIX)
> 

## 🍅 카프카 환경 파라미터 구분 및 kafka-configs 명령어로 파라미터 검색 및 수정 적용하기

카프가 config는 다음과 같이 크게 두 가지 영역으로 나눌 수 있다.

| Config 구분 | 설명 |
| --- | --- |
| Broker와 Topic 레벨 Config | - Kafka 서버에서 설정되는 Config
- Topic의 Config 값은 Broker 레벨에서 지정한 Config를 기본으로 설정하며 별도의 Topic 레벨 Config를 설정할 경우 이를 따름
- 보통 server.prperties에 있는 Config는 변경 시 Broker 재기동이 필요한 Config이며, Dynamic Config는 kafka-configs를 이용하여 동적으로 config 변경 가능 |
| Producer와 Consumer 레벨 Config | - Kafka 클라이언트에서 설정되는 Config
- Client 레벨에서 설정되므로 server.properties에 존재하지 않고, kafka-configs로 수정할 수 없으며 Client 수행시마다 설정할 수 있음 |

### 서버 측 설정(Broker와 Topic 레벨 Config)

브로커 레벨 설정은 카프카 서버 자체의 설정이다.

- 카프카 서버(브로커)에서 직접 설정된다.
- Topic의 기본 설정값을 제공한다.
- 설정 방식에 따라 두 가지로 구분된다.
    - Static Config : `server.properties` 파일에 있으며, 변경 시 브로커 재시작이 필요
    - Dynamic Config : `kafka-configs` 도구를 사용해 서버 재시작 없이 동적으로 변경 가능하다.

Topic 레벨 설정 :

- 기본적으로 브로커 레벨의 설정 값을 상속받는다.
- 필요한 경우 개별 토픽마다 별도의 설정을 적용할 수 있다.
- 토픽별 설정이 브로커 레벨 설정보다 우선한다.

### 클라이언트 측 설정(Producer와 Consumer 레벨 Config)

- 카프카 클라이언트 애플리케이션에서 설정된다.
- 서버 설정(`server.properties`)와는 완전히 별개이다.
- `kafka-configs` 도구로는 변경할 수 없다.
- 클라이언트 애플리케이션 코드 내에서 설정되며, 실행할 때마다 적용할 수 있다.
- 각 클라이언트(Producer/Consumer)마다 독립적으로 설정 가능하다.

## 🍅 kafka-configs 사용하기

> 교재 chapter3의 내용
> 

### config 값 확인하기

```bash
kafka-configs --bootstrap-server [hostIp:port] --entity-type [borkers/topics] --entity-name [broker id / topic name] --all --describe
```

예시

- default로 아무런 설정을 안해줬으면 broker id는 0이다.
- broker에 있는 모든 config들이 출력된다.
- `grep` 과 함께 활용하면 원하는 값의 확인이 바로 가능하다.

```bash
$ kafka-configs --bootstrap-server localhost:9092 --entity-type brokers --entity-name 0 --all --describe
All configs for broker 0 are:
  log.cleaner.min.compaction.lag.ms=0 sensitive=false synonyms={DEFAULT_CONFIG:log.cleaner.min.compaction.lag.ms=0}
  offsets.topic.num.partitions=50 sensitive=false synonyms={DEFAULT_CONFIG:offsets.topic.num.partitions=50}      
  sasl.oauthbearer.jwks.endpoint.refresh.ms=3600000 sensitive=false synonyms={DEFAULT_CONFIG:sasl.oauthbearer.jwks.endpoint.refresh.ms=3600000}
  log.flush.interval.messages=9223372036854775807 sensitive=false synonyms={DEFAULT_CONFIG:log.flush.interval.messages=9223372036854775807}
  controller.socket.timeout.ms=30000 sensitive=false synonyms={DEFAULT_CONFIG:controller.socket.timeout.ms=30000}  principal.builder.class=org.apache.kafka.common.security.authenticator.DefaultKafkaPrincipalBuilder sensitive=false synonyms={DEFAULT_CONFIG:principal.builder.class=org.apache.kafka.common.security.authenticator.DefaultKafkaPrincipalBuilder}
  log.flush.interval.ms=null sensitive=false synonyms={}
  controller.quorum.request.timeout.ms=2000 sensitive=false synonyms={DEFAULT_CONFIG:controller.quorum.request.timeout.ms=2000}
  sasl.oauthbearer.expected.audience=null sensitive=false synonyms={}
  min.insync.replicas=1 sensitive=false synonyms={DEFAULT_CONFIG:min.insync.replicas=1}
  num.recovery.threads.per.data.dir=1 sensitive=false synonyms={STATIC_BROKER_CONFIG:num.recovery.threads.per.data.dir=1, DEFAULT_CONFIG:num.recovery.threads.per.data.dir=1}
  ssl.keystore.type=JKS sensitive=false synonyms={DEFAULT_CONFIG:ssl.keystore.type=JKS}                          ings
  zookeeper.ssl.protocol=TLSv1.2 sensitive=false synonyms={DEFAULT_CONFIG:zookeeper.ssl.protocol=TLSv1.2}        
  sasl.mechanism.inter.broker.protocol=GSSAPI sensitive=false synonyms={DEFAULT_CONFIG:sasl.mechanism.inter.broker.protocol=GSSAPI}
  metadata.log.segment.bytes=1073741824 sensitive=false synonyms={DEFAULT_CONFIG:metadata.log.segment.bytes=1073741824}
  fetch.purgatory.purge.interval.requests=1000 sensitive=false synonyms={DEFAULT_CONFIG:fetch.purgatory.purge.interval.requests=1000}
  ssl.endpoint.identification.algorithm=https sensitive=false synonyms={DEFAULT_CONFIG:ssl.endpoint.identification.algorithm=https}
  zookeeper.ssl.keystore.location=null sensitive=false synonyms={}
  replica.socket.timeout.ms=30000 sensitive=false synonyms={DEFAULT_CONFIG:replica.socket.timeout.ms=30000}      
  message.max.bytes=1048588 sensitive=false synonyms={DEFAULT_CONFIG:message.max.bytes=1048588}
  max.connection.creation.rate=2147483647 sensitive=false synonyms={DEFAULT_CONFIG:max.connection.creation.rate=2147483647}
  connections.max.reauth.ms=0 sensitive=false synonyms={DEFAULT_CONFIG:connections.max.reauth.ms=0}
  log.flush.offset.checkpoint.interval.ms=60000 sensitive=false synonyms={DEFAULT_CONFIG:log.flush.offset.checkpoint.interval.ms=60000}
  zookeeper.clientCnxnSocket=null sensitive=false synonyms={}
  zookeeper.ssl.client.enable=false sensitive=false synonyms={DEFAULT_CONFIG:zookeeper.ssl.client.enable=false}  
  quota.window.num=11 sensitive=false synonyms={DEFAULT_CONFIG:quota.window.num=11}
  sasl.oauthbearer.clock.skew.seconds=30 sensitive=false synonyms={DEFAULT_CONFIG:sasl.oauthbearer.clock.skew.seconds=30}
  zookeeper.connect=localhost:2181 sensitive=false synonyms={STATIC_BROKER_CONFIG:zookeeper.connect=localhost:2181}
  authorizer.class.name= sensitive=false synonyms={DEFAULT_CONFIG:authorizer.class.name=}
  password.encoder.secret=null sensitive=true synonyms={}
  num.replica.fetchers=1 sensitive=false synonyms={DEFAULT_CONFIG:num.replica.fetchers=1}
  alter.log.dirs.replication.quota.window.size.seconds=1 sensitive=false synonyms={DEFAULT_CONFIG:alter.log.dirs.replication.quota.window.size.seconds=1}
  sasl.oauthbearer.jwks.endpoint.url=null sensitive=false synonyms={}
  log.roll.jitter.hours=0 sensitive=false synonyms={DEFAULT_CONFIG:log.roll.jitter.hours=0}
  password.encoder.old.secret=null sensitive=true synonyms={}
  log.cleaner.delete.retention.ms=86400000 sensitive=false synonyms={DEFAULT_CONFIG:log.cleaner.delete.retention.ms=86400000}
  sasl.login.retry.backoff.ms=100 sensitive=false synonyms={DEFAULT_CONFIG:sasl.login.retry.backoff.ms=100}      
  queued.max.requests=500 sensitive=false synonyms={DEFAULT_CONFIG:queued.max.requests=500}
  log.cleaner.threads=1 sensitive=false synonyms={DEFAULT_CONFIG:log.cleaner.threads=1}
  sasl.kerberos.service.name=null sensitive=false synonyms={}
  socket.request.max.bytes=104857600 sensitive=false synonyms={STATIC_BROKER_CONFIG:socket.request.max.bytes=104857600, DEFAULT_CONFIG:socket.request.max.bytes=104857600}
  log.message.timestamp.type=CreateTime sensitive=false synonyms={DEFAULT_CONFIG:log.message.timestamp.type=CreateTime}
  zookeeper.ssl.keystore.type=null sensitive=false synonyms={}
  connections.max.idle.ms=600000 sensitive=false synonyms={DEFAULT_CONFIG:connections.max.idle.ms=600000}        
  zookeeper.set.acl=false sensitive=false synonyms={DEFAULT_CONFIG:zookeeper.set.acl=false}
  delegation.token.expiry.time.ms=86400000 sensitive=false synonyms={DEFAULT_CONFIG:delegation.token.expiry.time.ms=86400000}
  max.connections=2147483647 sensitive=false synonyms={DEFAULT_CONFIG:max.connections=2147483647}
  transaction.state.log.num.partitions=50 sensitive=false synonyms={DEFAULT_CONFIG:transaction.state.log.num.partitions=50}
  controller.quorum.election.timeout.ms=1000 sensitive=false synonyms={DEFAULT_CONFIG:controller.quorum.election.timeout.ms=1000}
  listener.security.protocol.map=PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL sensitive=false synonyms={DEFAULT_CONFIG:listener.security.protocol.map=PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL}
  log.retention.hours=168 sensitive=false synonyms={STATIC_BROKER_CONFIG:log.retention.hours=168, DEFAULT_CONFIG:log.retention.hours=168}
  client.quota.callback.class=null sensitive=false synonyms={}
  ssl.provider=null sensitive=false synonyms={}
  delete.records.purgatory.purge.interval.requests=1 sensitive=false synonyms={DEFAULT_CONFIG:delete.records.purgatory.purge.interval.requests=1}
  log.roll.ms=null sensitive=false synonyms={}
  ssl.cipher.suites= sensitive=false synonyms={DEFAULT_CONFIG:ssl.cipher.suites=}
  controller.quorum.retry.backoff.ms=20 sensitive=false synonyms={DEFAULT_CONFIG:controller.quorum.retry.backoff.ms=20}
  password.encoder.cipher.algorithm=AES/CBC/PKCS5Padding sensitive=false synonyms={DEFAULT_CONFIG:password.encoder.cipher.algorithm=AES/CBC/PKCS5Padding}
  ssl.principal.mapping.rules=DEFAULT sensitive=false synonyms={DEFAULT_CONFIG:ssl.principal.mapping.rules=DEFAULT}
  replica.selector.class=null sensitive=false synonyms={}
  max.connections.per.ip=2147483647 sensitive=false synonyms={DEFAULT_CONFIG:max.connections.per.ip=2147483647}  
  background.threads=10 sensitive=false synonyms={DEFAULT_CONFIG:background.threads=10}
  request.timeout.ms=30000 sensitive=false synonyms={DEFAULT_CONFIG:request.timeout.ms=30000}
  log.message.format.version=3.0-IV1 sensitive=false synonyms={DEFAULT_CONFIG:log.message.format.version=3.0-IV1}  sasl.login.class=null sensitive=false synonyms={}
  log.dir=/tmp/kafka-logs sensitive=false synonyms={DEFAULT_CONFIG:log.dir=/tmp/kafka-logs}
  log.segment.bytes=1073741824 sensitive=false synonyms={STATIC_BROKER_CONFIG:log.segment.bytes=1073741824, DEFAULT_CONFIG:log.segment.bytes=1073741824}
  replica.fetch.response.max.bytes=10485760 sensitive=false synonyms={DEFAULT_CONFIG:replica.fetch.response.max.bytes=10485760}
  group.max.session.timeout.ms=1800000 sensitive=false synonyms={DEFAULT_CONFIG:group.max.session.timeout.ms=1800000}
  controller.listener.names=null sensitive=false synonyms={}
  controller.quorum.append.linger.ms=25 sensitive=false synonyms={DEFAULT_CONFIG:controller.quorum.append.linger.ms=25}
  log.segment.delete.delay.ms=60000 sensitive=false synonyms={DEFAULT_CONFIG:log.segment.delete.delay.ms=60000}  
  log.retention.minutes=null sensitive=false synonyms={}
  log.dirs=/home/vboxuser/data/kafka-logs sensitive=false synonyms={STATIC_BROKER_CONFIG:log.dirs=/home/vboxuser/data/kafka-logs}
  controlled.shutdown.enable=true sensitive=false synonyms={DEFAULT_CONFIG:controlled.shutdown.enable=true}      
  socket.connection.setup.timeout.max.ms=30000 sensitive=false synonyms={DEFAULT_CONFIG:socket.connection.setup.timeout.max.ms=30000}
  log.message.timestamp.difference.max.ms=9223372036854775807 sensitive=false synonyms={DEFAULT_CONFIG:log.message.timestamp.difference.max.ms=9223372036854775807}
  sasl.oauthbearer.scope.claim.name=scope sensitive=false synonyms={DEFAULT_CONFIG:sasl.oauthbearer.scope.claim.name=scope}
  password.encoder.key.length=128 sensitive=false synonyms={DEFAULT_CONFIG:password.encoder.key.length=128}      
  sasl.login.refresh.min.period.seconds=60 sensitive=false synonyms={DEFAULT_CONFIG:sasl.login.refresh.min.period.seconds=60}
  sasl.oauthbearer.expected.issuer=null sensitive=false synonyms={}
  sasl.login.read.timeout.ms=null sensitive=false synonyms={}
  transaction.abort.timed.out.transaction.cleanup.interval.ms=10000 sensitive=false synonyms={DEFAULT_CONFIG:transaction.abort.timed.out.transaction.cleanup.interval.ms=10000}
  sasl.kerberos.kinit.cmd=/usr/bin/kinit sensitive=false synonyms={DEFAULT_CONFIG:sasl.kerberos.kinit.cmd=/usr/bin/kinit}
  log.cleaner.io.max.bytes.per.second=1.7976931348623157E308 sensitive=false synonyms={DEFAULT_CONFIG:log.cleaner.io.max.bytes.per.second=1.7976931348623157E308}
  auto.leader.rebalance.enable=true sensitive=false synonyms={DEFAULT_CONFIG:auto.leader.rebalance.enable=true}  
  leader.imbalance.check.interval.seconds=300 sensitive=false synonyms={DEFAULT_CONFIG:leader.imbalance.check.interval.seconds=300}
  log.cleaner.min.cleanable.ratio=0.5 sensitive=false synonyms={DEFAULT_CONFIG:log.cleaner.min.cleanable.ratio=0.5}
  replica.lag.time.max.ms=30000 sensitive=false synonyms={DEFAULT_CONFIG:replica.lag.time.max.ms=30000}
  num.network.threads=3 sensitive=false synonyms={STATIC_BROKER_CONFIG:num.network.threads=3, DEFAULT_CONFIG:num.network.threads=3}    
```

### config 값 설정하기

`--add-config` 옵션을 사용한다.

```bash
kafka-configs --bootstrap-server [hostIp:port] --entity-type [brokers/topics] --entity-name [broker id / topic name] --alter --add-config property명=value
```

예시

- `max.message.bytes` 속성 값을 수정해보자.

```bash
$ kafka-configs --bootstrap-server localhost:9092 --entity-type topics --entity-name multipart-topic --alter --add-config max.message.bytes=2088000
Completed updating config for topic multipart-topic.
```

- 그리고 값이 바뀌었는지 확인해보면 `max.message.bytes=2088000` 를 확인할 수 있다.

```bash
$ kafka-configs --bootstrap-server localhost:9092 --entity-type topics --entity-name multipart-topic --all --describe | grep max.message
  max.message.bytes=2088000 sensitive=false synonyms={DYNAMIC_TOPIC_CONFIG:max.message.bytes=2088000, DEFAULT_CONFIG:message.max.bytes=1048588}
```

### config 값 unset

다시 default 값으로 돌리겠다는 의미이다. `--delete-config` 옵션을 사용한다.

```bash
kafka-configs --bootstrap-server [hostIp:port] --entity-type [brokers/topics] --entity-name [broker id / topics name] --alter --delete-config property명
```

예시

- 위의 예시에서 다시 원복을 시켜보자.

```bash
$ kafka-configs --bootstrap-server localhost:9092 --entity-type topics --entity-name multipart-topic --alter --delete-config max.message.bytes
Completed updating config for topic multipart-topic.
```

- 그리고 확인해보면 default로 돌아와있는 것을 확인할 수 있다.

```bash
$ kafka-configs --bootstrap-server localhost:9092 --entity-type topics --entity-name multipart-topic --all --describe | grep max.message
  max.message.bytes=1048588 sensitive=false synonyms={DEFAULT_CONFIG:message.max.bytes=1048588}
```

## 🍅 kafka-dump-log 명령어로 로그 파일의 메시지 내용 확인하기

`kafka-dumg-log` 명령어로 log 파일 내부를 확인해보자.

kafka의 log는 partition 단위로, `server.properties` 에서 지정된 로그 경로에 저장된다.

```bash
$ kafka-dump-log --deep-iteration --files /home/vboxuser/data/kafka-logs/multipart-topic-0/00000000000000000000.log --print-data-log
| offset: 574 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 574 headerKeys: [] payload: test nonkey message sent test00000000000000 1465
| offset: 575 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 575 headerKeys: [] payload: test nonkey message sent test00000000000000 1466
| offset: 576 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 576 headerKeys: [] payload: test nonkey message sent test00000000000000 1467
| offset: 577 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 577 headerKeys: [] payload: test nonkey message sent test00000000000000 1468
| offset: 578 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 578 headerKeys: [] payload: test nonkey message sent test00000000000000 1469
| offset: 579 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 579 headerKeys: [] payload: test nonkey message sent test00000000000000 1470
| offset: 580 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 580 headerKeys: [] payload: test nonkey message sent test00000000000000 1471
| offset: 581 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 581 headerKeys: [] payload: test nonkey message sent test00000000000000 1472
| offset: 582 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 582 headerKeys: [] payload: test nonkey message sent test00000000000000 1473
| offset: 583 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 583 headerKeys: [] payload: test nonkey message sent test00000000000000 1474
| offset: 584 CreateTime: 1743388057301 keySize: -1 valueSize: 48 sequence: 584 headerKeys: [] payload: test nonkey message sent test00000000000000 1475
| offset: 585 CreateTime: 1743388057301 key .....
```

## 🍅 Java 기반에서 Producer 구현하기

### Java Producer Client API 처리 로직 개요

> 동일한 오류 발생했었음 : https://www.inflearn.com/community/questions/1156453/kafka-%EC%97%B0%EA%B2%B0-%EC%A7%88%EB%AC%B8-%EB%93%9C%EB%A6%BD%EB%8B%88%EB%8B%A4?srsltid=AfmBOorDLpHT0xkQq79NQRLfcOEw7im63eZEcdn2iMmFAEVumLOPxnSq
> 
1. Producer 환경 설정(Properties 객체를 이용)
    - 필수 값
        - `boostrap.servers: xxx`
        - `key.serializer.class: ....`
        - `value.serializer.class: ....`
    - 선택 값
        - `acks: xxx`
        - `Batch.size: ....`
2. 1에서 설정한 환경 설정 값을 반영하여 KafkaProducer 객체 생성
3. Topic 명과 메시지 값(key, value)을 입력하여 보낼 메시지인 ProducerRecord 객체 생성
4. KafkaProducer 객체의 `send()` 메소드를 호출하여 ProducerRecord 전송
5. KafkaProducer 객체의 `close()` 메소드를 호출하여 종료

> 다음 코드는 `simple-topic` 토픽에 `hello world` 값을 전송한다.
> 

```java
public class SimpleProducer {
    public static void main(String [] args) {
        String topicName="simple-topic";

        //KafaProducer configuration setting
        // null, "hello world"

        Properties props = new Properties();
        //bootstra.servers, key.serialization.class, value.serializer.class
        //props.setProperty("bootstrap.servers", "192.168.56.101:9092");
        props.setProperty(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "192.168.56.101:9092");
        props.setProperty(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.setProperty(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

        //KafkaProducer object create
        KafkaProducer<String, String> kafkaProducer = new KafkaProducer<String, String>(props);

        //ProducerRecord object create
        ProducerRecord<String, String> producerRecord = new ProducerRecord<>(topicName, "hello world");

        //KafkaProducer message send
        kafkaProducer.send(producerRecord);

        kafkaProducer.flush();
        kafkaProducer.close();
    }
}

```

코드를 실행하고 다음 명령어로 consuming 해보면, 적절히 메시지가 전송된 것을 확인할 수 있다.

```bash
$ kafka-console-consumer --bootstrap-server localhost:9092 --t
opic simple-topic --from-beginning
hello world
hello world 2
```

## 🍅 Producer Java 클라이언트 API 내부를 IntelliJ Debugger를 이용하여 살짝 뜯어보기

### Kafka Producer의 send() 메소드 호출 프로세스

- Kafka Producer 전송은 Producer Client의 별도 Thread가 전송을 담당한다는 점에서 기본적으로 Thread간 Async 전송임
- 즉 Producer Client의 Main Thread가 `send()` 메소드를 호출하여 메시지 전송을 시작하지만 바로 전송되지 않으며 내부 Buffer에 메시지를 저장 후에(배치로) 별도의 Thread가 Kafka Broker에 실제 전송을 하는 방식임

![image.png](https://github.com/user-attachments/assets/cfa254b7-1fc2-46d0-b658-7779eff97074)

해당 로직을 조금 더 상세하게 풀어보면 다음과 같다.


![image.png](https://github.com/user-attachments/assets/9cf1a63f-5dfa-478f-9750-bb4ecf29c0c9)

디버깅을 통해서 내부 프로세스를 살펴봐보자.

KafkaProducer를 실행시키면 `kafka-producer-network-thread` 스레드 하나가 추가된 것을 확인할 수 있다.


![image.png](https://github.com/user-attachments/assets/ebc0b879-80ff-460d-852d-10be13dbeddf)

## 🍅 Producer와 Broker 와의 메시지 동기화/비동기화 전송

![image.png](https://github.com/user-attachments/assets/3227fb10-e6f5-4d61-bfc4-56d80a48d022)

### Sync(동기 방식)

- Producer는 브로커로부터 해당 메시지를 성공적으로 받았다는 ACK 메시지를 받은 후 다음 메시지를 전송
- `KafkaProducer.send().**get()**` 호출하여 브로커로부터 ACK 메시지를 받을 때까지 **대기(Wait)** 함

### ASync(비동기 방식)

- Producer는 브로커로부터 해당 메시지를 성공적으로 받았다는 ACK 메시지를 기다리지 않고 전송
- 브로커로부터 ACK 메시지를 비동기로 Producer에 받기 위해서 Callback을 적용함
- `send()` 메소드 호출 시에 callback 객체를 인자로 입력하여 ACK 메시지를 Producer로 전달 받을 수 있음

## 🍅 Producer의 메시지 동기화 전송

기본적으로는 비동기 호출이다.

```java
Future<RecordMetaData> = KafkaProducer.send()
```

Future 객체의 `get()` 을 호출하여, 브로커로부터 메시지 ACK 응답을 받을 때까지 Main Thread를 대기시키는 방식으로 동기화를 구성한다.

> 전송에 대한 안정성은 높지만, 전송 성능이 느려진다.
> 

### RecordMetadata란?

RecordMetadata란 Kafka **Producer가 메시지를 성공적으로 전송한 후 받는 중요한 메타데이터 객체**이다. 이 객체는 전송된 레코드(메시지)에 대한 중요한 정보를 담고 있다.

- 토픽(Topic) : 메시지가 전송된 토픽 이름
- 파티션(Partition) : 메시지가 저장된 파티션 번호
- 오프셋(Offset) : 파티션 내 메시지의 고유 위치 식별자
- 타임스탬프(Timestamp) : 메시지가 브로커에 추가된 시간
- 체크섬(Checksum) : 데이터 무결성 검증을 위한 값
- 직렬화된 키/값 크기(Serialized Key/Value Size) : 직렬화된 메시지 키와 값의 크기(바이트)

### Producer와 브로커 메시지 동기화 코드 1

```java
Future<RecordMetaData> future = KafkaProducer.send();
RecordMetaData recordMetadata = future.get();
```

### Producer와 브로커 메시지 동기화 코드 2

```java
RecordMetaData recordMetadata = KafkaProducer.send().get();
```

정리하면, 동기식 호출은 `producer.send(record).get()` 형태로 사용하며, 결과를 기다리며 스레드가 블로킹된다. try-catch를 필수로 사용하여 Exception 처리가 필요하다.

> send가 성공하면 metadata가, 실패하면 exception이 발생함
> 

예시

```java
public class SimpleProducerSync {
    public static final Logger logger = LoggerFactory.getLogger(SimpleProducerSync.class.getName());
    public static void main(String [] args) {
        String topicName="simple-topic";

        //KafaProducer configuration setting
        // null, "hello world"

        Properties props = new Properties();
        //bootstra.servers, key.serialization.class, value.serializer.class
        //props.setProperty("bootstrap.servers", "192.168.56.101:9092");
        props.setProperty(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "192.168.56.101:9092");
        props.setProperty(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.setProperty(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

        //KafkaProducer object create
        KafkaProducer<String, String> kafkaProducer = new KafkaProducer<String, String>(props);

        //ProducerRecord object create
        ProducerRecord<String, String> producerRecord = new ProducerRecord<>(topicName, "hello world 2");

        //KafkaProducer message send
        try {
            RecordMetadata recordMetadata = kafkaProducer.send(producerRecord).get();
            logger.info("\n ###### record metadata received ##### \n" +
                    "partition:" + recordMetadata.partition() + "\n" +
                    "offset:" + recordMetadata.offset() + "\n" +
                    "timestamp:" + recordMetadata.timestamp());
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        } finally {
            kafkaProducer.close();
        }

        kafkaProducer.flush();
        kafkaProducer.close();
    }
}

```

output

```bash
[main] INFO com.example.kafka.SimpleProducerSync - 
 ###### record metadata received ##### 
partition:0
offset:2
timestamp:1743484579742
[main] INFO org.apache.kafka.clients.producer.KafkaProducer - [Producer clientId=producer-1] Closing the Kafka producer with timeoutMillis = 9223372036854775807 ms.
[main] INFO org.apache.kafka.common.metrics.Metrics - Metrics scheduler closed
```

## 🍅 Producer의 메시지 비동기화 전송

Kafka는 Record를 쓴 뒤 해당 레코드의 토픽, 파티션 그리고 오프셋을 리턴하는데, 대부분의 애플리케이션에서는 이런 메타데이터가 필요 없다. 그러나 메시지 전송에 완전 실패했을 경우에는 그런 내용을 알아야 한다. 그래야 예외를 발생시키든지, 에러를 로그에 쓰든지, 아니면 사후 분석을 위해 에러 파일에 메시지를 쓰거나 할 수 있기 때문이다.

메시지를 비동기적으로 전송하고도 여전히 에러를 처리하는 경우를 위해 프로듀서는 레코드를 전송할 때 콜백을 지정할 수 있도록 한다.

### Callback의 이해

Producer의 비동기 전송 방식의 경우 Callback의 형식으로 ACK 메시지를 받는다. Callback이란 다른 코드의 인수로서 넘겨주는 **실행 가능한 코드**이며, 콜백을 넘겨받는 코드는 이 콜백을 필요에 따라 즉시 실행할 수도 있고, 아니면 나중에 실행할 수도 있다. 즉 Callback은 다른 함수의 인자로서 전달된 후에 특정 이벤트가 발생 시 해당 함수에서 다시 호출된다.

자바에서는

1. Callback을 Interface로 구성하고, 호출되어질 메서드를 선언
2. 해당 Callback을 구현하는 객체 생성. 즉 호출 되어질 메소드를 구체적으로 구현
3. 다른 함수의 인자로 해당 Callback을 인자로 전달
4. 해당 함수는 특정 이벤트 발생 시 Callback에 선언된 메소드를 호출

### Callback을 이용한 Producer와 브로커와의 메시지 전송/재전송

Producer Client가 만들어지면, 자동으로 Send Network Thread가 만들어진다. (전송만을 담당하는 별도의 네트워크 스레드가 만들어짐)

우리가 메시지를 하나 보내본다고 하자. 

![image.png](https://github.com/user-attachments/assets/f984a16a-5bd7-4f5e-af74-e6e9707b892c)

- 메시지를 보내면, Producer 메인 스레드는 callback 객체를 메시지와 함께 메모리로 보낸다.
- 그래서 Send 네트워크 스레드는 해당 메모리를 가지고 있고, 메시지를 브로커로 보내게 된다.
- 그리고 비동기 방식이기 때문에, 보낸 메시지의 ACK이 올 때까지 기다리지 않는다.
- Producer는 다시 다른 메시지를 보낸다.
- 그때 Broker가 메시지에 대한 ACK를 보내면, Send 네트워크 스레드가 callback의 내용을 채워주고 (성공했다면 offset 등의 메타데이터를, 실패했다면 exception을 채운다) 이게 메인 스레드에 전달이 된다.

> 내부적으로는 메모리를 보낸다기 보다는, 메모리 주소를 알고있기 때문에 해당 내용을 참조하는 것
> 

> Send 네트워크 스레드는 **ACK가 오지 않거나, retry 가능한 exception이 오면**, 메커니즘적으로 내부적으로 **재전송한다.** 이는 Sync, Async 방식에 관계없이 재전송을 한다.
> 

### Producer와 브로커와의 메시지 비동기화 전송 코드

Main 스레드에서 구현을 하지만, Send 네트워크 스레드에서 값을 호출을 해줘서 Callback의 값(metadata, exception)을 실질적으로 채워준다.

> `onComplemtion` 메서드는 sender 스레드에 의해 호출된다. (비동기적으로 불려진다)
> 

```java
kafkaProducer.send(producerRecord, new Callback() {
            @Override
            public void onCompletion(RecordMetadata recordMetadata, Exception e) {
                if (e == null) { //정상적으로 ACK을 받은 경우
                    logger.info("\n ###### record metadata received ##### \n" +
                            "partition:" + recordMetadata.partition() + "\n" +
                            "offset:" + recordMetadata.offset() + "\n" +
                            "timestamp:" + recordMetadata.timestamp());
                }
                else {
                    logger.error("exception error from broker " + e.getMessage());
                }
            }
        });
```

> Sync 방식은 느리기 때문에, 일반적으로 콜백을 이용한 Async 방식을 Producer에서 많이 활용한다.
> 

## 🍅 Key 값을 가지는 메시지 전송

Key값의 속성을 Integer로 수정해보자.

```java
public static void main(String [] args) {
        String topicName="simple-topic";

        //KafaProducer configuration setting
        // null, "hello world"

        Properties props = new Properties();
        //bootstra.servers, key.serialization.class, value.serializer.class
        //props.setProperty("bootstrap.servers", "192.168.56.101:9092");
        props.setProperty(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "192.168.56.101:9092");
        props.setProperty(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, IntegerSerializer.class.getName());
        props.setProperty(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());

        //KafkaProducer object create
        KafkaProducer<Integer, String> kafkaProducer = new KafkaProducer<Integer, String>(props);

        for (int seq=0; seq < 20; seq++) {
            //ProducerRecord object create
            ProducerRecord<Integer, String> producerRecord = new ProducerRecord<>(topicName, seq, "hello world " + seq);

            //KafkaProducer message send
            kafkaProducer.send(producerRecord, new Callback() {
                @Override
                public void onCompletion(RecordMetadata recordMetadata, Exception e) {
                    if (e == null) { //정상적으로 ACK을 받은 경우
                        logger.info("\n ###### record metadata received ##### \n" +
                                "partition:" + recordMetadata.partition() + "\n" +
                                "offset:" + recordMetadata.offset() + "\n" +
                                "timestamp:" + recordMetadata.timestamp());
                    } else {
                        logger.error("exception error from broker " + e.getMessage());
                    }
                }
            });
        }

        try {
            Thread.sleep(3000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        kafkaProducer.close();
    }
```

Key 값이 Integer인 경우는 String인 경우와 다르게 `--key-deserializer` 인자를 추가해줘야 한다. (Default가 StringDeserializer 이기 때문이다)

- String (default)

```bash
kafka-console-consumer --bootstrap-server localhost:9092 --group group-01 --topic multipart-topic \
--property print.key=true --property print.value=true 
```

- Integer

```bash
kafka-console-consumer --bootstrap-server localhost:9092 --group group-01 --topic multipart-topic \
--property print.key=true --property print.value=true \
--key-deserializer "org.apache.kafka.common.serialization.IntegerDeserializer
```

## 🍅 Acks 값 설정에 따른 Producer의 전송 방식 차이 이해

Producer는 해당 Topic의 Partition의 Leader Broker에게만 메시지를 보낸다.

### acks 0

> offset는 broker에 저장이 되었을 때 받는 값이기 때문에 알지 못한다.
> 
- Producer는 **Leader Broker가 메시지 A를 정상적으로 받았는지에 대한 ACK 메시지를 받지 않고** 다음 메시지인 메시지 B를 바로 전송
- 메시지가 제대로 전송되었는지 브로커로부터 확인을 받지 않기 때문에, 메시지가 브로커에 기록되지 않더라도 재전송하지 않음
- 메시지 손실의 우려가 가장 크지만, 가장 빠르게 전송할 수 있음(IoT 센서 데이터 등 데이터의 손실에 민감하지 않은 데이터 전송에 활용)

![image.png](https://github.com/user-attachments/assets/cdcb591a-6f09-4f51-b9cd-bb636d551477)

### acks 1

- Producer는 **Leader Broker가 메시지 A를 정상적으로 받았는지에 대한 ACK 메시지를 받은 후 다음 메시지인 메시지 B를 바로 전송**. 만약 오류 메시지를 브로커로부터 받으면 메시지 A를 재전송
- 메시지 A가 모든 Replicator에 완벽하게 복사 되었는 지의 여부는 확인하지 앟고 메시지 B를 전송
- 만약 Leader가 메시지를 복제 중에 다운될 경우 다음 Leader가 될 브로커에는 메시지가 없을 수 있기 때문에 메시지를 소실할 우려가 있음

![image.png](https://github.com/user-attachments/assets/4d17acea-36a3-49e8-93a9-24b08667ea15)

### acks all (default)

> `acks = -1` 과 동일하다.
> 
- Producer는 Leader Broker가 메시지 A를 정상적으로 받은 뒤 `min.insync.replicas` 개수 만큼의 Replicator에 복제를 수행한 뒤에 보내는 ACK 메시지를 받은 후 다음 메시지인 메시지 B를 바로 전송.
- 메시지 A가 **모든 Replicator에 완벽하게 복사되었는지의 여부까지 확인** 후에 메시지 B를 전송
- 메시지 손실이 되지 않도록 모든 장애 상황을 감안한 전송 모드이지만, ACK를 오래 기다려야 하므로 상대적으로 전송 속도가 느림

![image.png](https://github.com/user-attachments/assets/f2f566f9-d808-4e2b-9598-afc962a251a6)

### Producer의 Sync와 Callback Async에서의 acks와 retry

- Callback 기반의 async에서도 동일하게 acks 설정에 기반하여 retry가 수행됨
- Callback 기반의 async에서는 retry에 따라 Producer의 원래 메시지 전송 순서와 Broker에 기록되는 메시지 전송 순서가 변경될 수 있음
- Sync 방식에서 acks = 0일 경우 전송 후 ack/error를 기다리지 않음(fire and forget)
