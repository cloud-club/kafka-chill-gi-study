
// 흐름 1: 브로커 중심 복제 흐름
MERGE (a1:Concept {name: "브로커"})
MERGE (a2:Concept {name: "리더 선출"})
MERGE (a3:Concept {name: "ISR"})
MERGE (a4:Concept {name: "복제"})
MERGE (a1)-[:흐름]->(a2)
MERGE (a2)-[:흐름]->(a3)
MERGE (a3)-[:흐름]->(a4)

// 흐름 2: 프로듀서 → 로그 저장 흐름
MERGE (b1:Concept {name: "프로듀서"})
MERGE (b2:Concept {name: "파티셔너"})
MERGE (b3:Concept {name: "브로커"})
MERGE (b4:Concept {name: "로그 세그먼트"})
MERGE (b1)-[:흐름]->(b2)
MERGE (b2)-[:흐름]->(b3)
MERGE (b3)-[:흐름]->(b4)

// 흐름 3: 컨슈머 처리 흐름
MERGE (c1:Concept {name: "컨슈머"})
MERGE (c2:Concept {name: "오프셋"})
MERGE (c3:Concept {name: "컨슈머 그룹"})
MERGE (c4:Concept {name: "리밸런스"})
MERGE (c1)-[:흐름]->(c2)
MERGE (c2)-[:흐름]->(c3)
MERGE (c3)-[:흐름]->(c4)

// 흐름 4: 클러스터 제어 흐름 (ZooKeeper 기반)
MERGE (d1:Concept {name: "주키퍼"})
MERGE (d2:Concept {name: "컨트롤러"})
MERGE (d3:Concept {name: "메타데이터"})
MERGE (d4:Concept {name: "브로커"})
MERGE (d1)-[:흐름]->(d2)
MERGE (d2)-[:흐름]->(d3)
MERGE (d3)-[:흐름]->(d4)

// 흐름 5: KRaft 기반 클러스터 흐름
MERGE (e1:Concept {name: "KRaft 컨트롤러"})
MERGE (e2:Concept {name: "KRaft 로그"})
MERGE (e3:Concept {name: "메타데이터"})
MERGE (e4:Concept {name: "브로커"})
MERGE (e1)-[:흐름]->(e2)
MERGE (e2)-[:흐름]->(e3)
MERGE (e3)-[:흐름]->(e4)
