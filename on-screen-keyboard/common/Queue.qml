import QtQuick

QtObject {
    id: root

    property var front: null
    property var rear: null
    property int size: 0


    function enqueue(data: var) {
        const nodeComponent = Qt.createComponent("Node.qml");
        if (nodeComponent.status !== Component.Ready) return;

        const newNode = nodeComponent.createObject(root, {"data": data});
        if (this.isEmpty()) {
            front = newNode;
            rear = newNode;
        } else {
            rear.next = newNode;
            rear = newNode;
        }
        size++;
    }

    function dequeue(): var {
        if (isEmpty()) return null;

        const removedNode = front;
        front = front.next;

        if (front === null) {
            rear = null;
        }
        size--;

        return removedNode.data;
    }

    function peek(): var {
        if(isEmpty()) {
            return null;
        }

        return front.data;
    }

    function isEmpty(): bool {
        return size === 0;
    }
}
