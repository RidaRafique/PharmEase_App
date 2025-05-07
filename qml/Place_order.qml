import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Item {
    id: root
    anchors.fill: parent

    // Properties for order calculations
    property var currentTotal: 0
    property var discountAmount: 0
    property var discountedTotal: 0
    property int currentOrderId: -1

    // Arrays to store data
    property var medicineList: []
    property var orderItems: []
    property var customerInfo: ({})
    property bool customerFound: false

    // Calculate total based on order items
    function updateTotals() {
        var total = 0
        for (var i = 0; i < orderItems.length; i++) {
            total += orderItems[i].price * orderItems[i].quantity
        }
        currentTotal = total

        // Calculate discounted total
        discountedTotal = currentTotal - (currentTotal * discountAmount / 100)
    }

    // Load medicines from database
    function loadMedicines() {
        medicineList = dbManager.getAllMedicines()
        medicineListView.model = medicineList
    }

    // Search medicines by name
    function searchMedicines() {
        if (medicineSearch.text.trim() === "") {
            medicineList = dbManager.getAllMedicines()
        } else {
            medicineList = dbManager.searchMedicines(medicineSearch.text)
        }
        medicineListView.model = medicineList
    }

    // Add medicine to order
    function addToOrder(medicine) {
        // Check if already in order
        for (var i = 0; i < orderItems.length; i++) {
            if (orderItems[i].medID === medicine.medID) {
                // Check available stock
                if (orderItems[i].quantity < medicine.quantity) {
                    orderItems[i].quantity += 1
                    orderItemsView.model = null
                    orderItemsView.model = orderItems
                    updateTotals()
                } else {
                    messagePopup.text = "Cannot add more. Max available: " + medicine.quantity
                    messagePopup.open()
                }
                return
            }
        }

        // Add new item
        var item = {
            medID: medicine.medID,
            name: medicine.name,
            price: medicine.price,
            quantity: 1,
            available: medicine.quantity
        }

        orderItems.push(item)
        orderItemsView.model = null
        orderItemsView.model = orderItems
        updateTotals()
    }

    // Adjust quantity in order
    function adjustQuantity(index, change) {
        var newQuantity = orderItems[index].quantity + change

        if (newQuantity <= 0) {
            // Remove item
            orderItems.splice(index, 1)
        } else if (newQuantity <= orderItems[index].available) {
            // Update quantity
            orderItems[index].quantity = newQuantity
        } else {
            messagePopup.text = "Cannot add more. Max available: " + orderItems[index].available
            messagePopup.open()
            return
        }

        orderItemsView.model = null
        orderItemsView.model = orderItems
        updateTotals()
    }

    // Search for customer
    function searchCustomer() {
        var result = dbManager.getCustomerByNameOrPhone(customerSearch.text)

        if (result.name) {
            customerInfo = result
            customerFound = true
            notFoundMessage.visible = false
            customerNameField.text = result.name
            customerPhoneField.text = result.phone
        } else {
            customerFound = false
            notFoundMessage.visible = true
            customerInfo = {}
        }
    }

    // Save new customer
    function saveCustomer() {
        // Generate customer ID (normally this would come from the database)
        var customerId = Math.floor(Math.random() * 10000) + 1

        var success = dbManager.addCustomer(customerNameField.text, customerPhoneField.text, customerId)

        if (success) {
            customerInfo = {
                id: customerId,
                name: customerNameField.text,
                phone: customerPhoneField.text
            }
            customerFound = true
            notFoundMessage.visible = false
            actionMessage.text = "Customer added successfully!"
            actionMessage.color = "green"
            actionMessage.visible = true
        } else {
            actionMessage.text = "Failed to add customer"
            actionMessage.color = "red"
            actionMessage.visible = true
        }
    }

    // Process the order
    function placeOrder() {
        if (orderItems.length === 0) {
            messagePopup.text = "Please add items to order"
            messagePopup.open()
            return false
        }

        if (customerNameField.text === "") {
            messagePopup.text = "Please enter customer details"
            messagePopup.open()
            return false
        }

        return true
    }

    // Process payment and finalize order
    function processPayment(paymentMethod) {
        // Create new order
        var customerId = customerInfo.id || 0
        var total = discountAmount > 0 ? discountedTotal : currentTotal

        var orderId = dbManager.createOrder(
            customerNameField.text,
            customerId,
            customerPhoneField.text,
            total,
            paymentMethod
        )

        if (orderId > 0) {
            // Store order ID for invoice
            currentOrderId = orderId

            // Add items to order
            var allSuccess = true

            for (var i = 0; i < orderItems.length; i++) {
                var success = dbManager.addOrderItem(
                    orderId,
                    orderItems[i].medID,
                    orderItems[i].quantity,
                    orderItems[i].price
                )

                if (!success) {
                    allSuccess = false
                    messagePopup.text = "Error adding " + orderItems[i].name + " to order"
                    messagePopup.open()
                    break
                }
            }

            // Apply discount if any
            if (allSuccess && discountAmount > 0) {
                if (!dbManager.applyDiscount(orderId, discountAmount)) {
                    messagePopup.text = "Error applying discount"
                    messagePopup.open()
                    return false
                }
            }

            if (allSuccess) {
                // Open invoice window
                generateInvoice(orderId)

                return true
            }
        } else {
            messagePopup.text = "Error creating order"
            messagePopup.open()
        }

        return false
    }

    // Generate invoice for order

    function generateInvoice(orderId) {

        // Get order details from database

        var orderDetails = dbManager.getOrderDetails(orderId)



        if (!orderDetails || !orderDetails.orderID) {

            messagePopup.text = "Error retrieving order details for invoice."

            messagePopup.open()

            return

        }



        // Pass the order data to the invoice view

        invoiceWindow.orderId = orderId

        invoiceWindow.orderDetails = orderDetails



        // Explicitly set customer details

        invoiceWindow.customerName = customerNameField.text

        invoiceWindow.customerPhone = customerPhoneField.text



        // Make a deep copy of the order items to avoid reference issues

        var itemsCopy = []

        for (var i = 0; i < orderItems.length; i++) {

            itemsCopy.push({

                medID: orderItems[i].medID,

                name: orderItems[i].name,

                price: orderItems[i].price,

                quantity: orderItems[i].quantity,

                available: orderItems[i].available

            })

        }

        invoiceWindow.orderItems = itemsCopy



        // Set financial details

        invoiceWindow.discountAmount = discountAmount
        invoiceWindow.totalAmount = currentTotal
        invoiceWindow.discountedTotal = discountedTotal
        // Explicitly set payment method

        invoiceWindow.paymentMethod = paymentMethodPopup.paymentMethodSelected

        // Show the invoice window

        invoiceWindow.visible = true

        // Clear the order after successful processing

        clearOrder()

    }
    // Clear the current order
    function clearOrder() {
        orderItems = []
        orderItemsView.model = null
        currentTotal = 0
        discountAmount = 0
        discountedTotal = 0
        discountField.text = ""

        // Reload medicines to get updated stock
        loadMedicines()
    }

    // Main layout
    Rectangle {
        anchors.fill: parent
        color: "#daeae6"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            // Title
            Text {
                text: "Place Order"
                font.pixelSize: 40
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            // Main content
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 20

                // Left column
                ColumnLayout {
                    Layout.preferredWidth: parent.width / 2 - 10
                    Layout.fillHeight: true
                    spacing: 20

                    // Medicine search section
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        border.color: "black"
                        radius: 10

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 10

                            Text {
                                text: "Search Medicine:"
                                font.pixelSize: 24
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                spacing: 10

                                TextField {
                                    id: medicineSearch
                                    Layout.fillWidth: true
                                    placeholderText: "Enter medicine name..."
                                    onAccepted: searchMedicines()
                                }

                                Button {
                                    text: "Search"
                                    onClicked: searchMedicines()
                                }
                            }

                            ListView {
                                id: medicineListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 10

                                delegate: Rectangle {
                                    width: medicineListView.width
                                    height: 50
                                    color: "lightgray"
                                    radius: 5

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name + " (Rs." + modelData.price + ") - Available: " + modelData.quantity
                                            font.pixelSize: 16
                                        }

                                        Button {
                                            text: "Add"
                                            enabled: modelData.quantity > 0
                                            onClicked: addToOrder(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Customer details section
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 300
                        border.color: "black"
                        radius: 10

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 10

                            Text {
                                text: "Customer Details:"
                                font.pixelSize: 24
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                spacing: 10

                                TextField {
                                    id: customerSearch
                                    Layout.fillWidth: true
                                    placeholderText: "Search Customer by Name/ID..."
                                    onAccepted: searchCustomer()
                                }

                                Button {
                                    text: "Search"
                                    onClicked: searchCustomer()
                                }
                            }

                            Text {
                                id: notFoundMessage
                                text: "Customer Not Found"
                                color: "red"
                                font.pixelSize: 16
                                visible: false
                            }

                            Text {
                                id: actionMessage
                                font.pixelSize: 16
                                color: "green"
                                visible: false
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 10

                                Text {
                                    text: "Customer Name:"
                                    font.pixelSize: 14
                                }

                                TextField {
                                    id: customerNameField
                                    Layout.fillWidth: true
                                    placeholderText: "Enter customer name"
                                }

                                Text {
                                    text: "Phone Number:"
                                    font.pixelSize: 14
                                }

                                TextField {
                                    id: customerPhoneField
                                    Layout.fillWidth: true
                                    placeholderText: "Enter phone number"
                                }
                            }

                            Button {
                                id: saveCustomerButton
                                text: "Save Customer"
                                Layout.alignment: Qt.AlignRight
                                visible: notFoundMessage.visible
                                enabled: customerNameField.text !== "" && customerPhoneField.text !== ""
                                onClicked: saveCustomer()
                            }
                        }
                    }
                }

                // Right column
                ColumnLayout {
                    Layout.preferredWidth: parent.width / 2 - 10
                    Layout.fillHeight: true
                    spacing: 20

                    // Order items section
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        border.color: "black"
                        radius: 10

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 10

                            Text {
                                text: "Order Items:"
                                font.pixelSize: 24
                                font.bold: true
                            }

                            ListView {
                                id: orderItemsView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 10

                                delegate: Rectangle {
                                    width: orderItemsView.width
                                    height: 50
                                    color: "lightgray"
                                    radius: 5

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name + " (Rs." + modelData.price + " x " + modelData.quantity + ")"
                                            font.pixelSize: 16
                                        }

                                        Button {
                                            text: "+"
                                            onClicked: adjustQuantity(index, 1)
                                            enabled: modelData.quantity < modelData.available
                                        }

                                        Button {
                                            text: "-"
                                            onClicked: adjustQuantity(index, -1)
                                        }

                                        Button {
                                            text: "Remove"
                                            onClicked: {
                                                orderItems.splice(index, 1)
                                                orderItemsView.model = null
                                                orderItemsView.model = orderItems
                                                updateTotals()
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Total: Rs. " + currentTotal
                                font.pixelSize: 18
                                font.bold: true
                                Layout.alignment: Qt.AlignRight
                            }
                        }
                    }

                    // Payment details section
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 300
                        border.color: "black"
                        radius: 10

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 10

                            Text {
                                text: "Payment Details:"
                                font.pixelSize: 24
                                font.bold: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: "Discount (%):"
                                    font.pixelSize: 16
                                }

                                TextField {
                                    id: discountField
                                    Layout.fillWidth: true
                                    placeholderText: "Enter discount percentage"
                                    validator: IntValidator { bottom: 0; top: 100 }
                                    inputMethodHints: Qt.ImhDigitsOnly
                                }

                                Button {
                                    text: "Apply"
                                    onClicked: {
                                        if (discountField.text !== "") {
                                            discountAmount = parseInt(discountField.text)
                                            updateTotals()
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Discount: " + discountAmount + "% (-Rs. " + (currentTotal * discountAmount / 100) + ")"
                                font.pixelSize: 16
                                visible: discountAmount > 0
                            }

                            Text {
                                text: "Total Payable: Rs. " + (discountAmount > 0 ? discountedTotal : currentTotal)
                                font.pixelSize: 20
                                font.bold: true
                            }

                            Item { Layout.fillHeight: true }

                            Button {
                                text: "Place Order"
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 200
                                Layout.preferredHeight: 60
                                font.pixelSize: 18
                                background: Rectangle {
                                    color: "#4f9c9c"
                                    radius: 10
                                }
                                onClicked: {
                                    if (placeOrder()) {
                                        paymentMethodPopup.open()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Button {
                id: backButton
                text: "Back"
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: 80
                Layout.preferredHeight: 40
                onClicked: stackView.pop()
            }
        }

        // Payment Method Popup
        Popup {
            id: paymentMethodPopup
            anchors.centerIn: parent
            width: 400
            height: 200
            modal: true
            closePolicy: Popup.CloseOnEscape
            property string paymentMethodSelected: "Cash"

            Rectangle {
                anchors.fill: parent
                color: "white"
                border.color: "black"
                radius: 10

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    Text {
                        text: "Select Payment Method"
                        font.pixelSize: 20
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    ComboBox {
                        id: paymentMethod
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 200
                        model: ["Cash", "Card", "Online"]
                        onCurrentTextChanged: {
                            paymentMethodPopup.paymentMethodSelected = currentText
                        }
                    }

                    Text {
                        text: "Total Amount: Rs. " + (discountAmount > 0 ? discountedTotal : currentTotal)
                        font.pixelSize: 18
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 20

                        Button {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 50
                            text: "Cancel"
                            Layout.preferredWidth: 120
                            implicitHeight: 40
                            onClicked: paymentMethodPopup.close()
                        }

                        Button {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 50
                            text: "Confirm Payment"
                            Layout.preferredWidth: 160
                            implicitHeight: 40
                            onClicked: {
                                if (processPayment(paymentMethodPopup.paymentMethodSelected)) {
                                    paymentMethodPopup.close()
                                }
                            }
                        }
                    }
                }
            }
        }

        // Message Popup
        Popup {
            id: messagePopup
            anchors.centerIn: parent
            width: 400
            height: 200
            modal: true
            closePolicy: Popup.CloseOnEscape
            property alias text: messageText.text

            Rectangle {
                anchors.fill: parent
                color: "white"
                border.color: "black"
                radius: 10

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    Text {
                        id: messageText
                        font.pixelSize: 18
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    }

                    Button {
                        text: "OK"
                        Layout.preferredWidth: 100
                        Layout.preferredHeight: 40
                        Layout.alignment: Qt.AlignHCenter
                        onClicked: messagePopup.close()
                    }
                }
            }
        }
    }

    // Invoice Window with dynamic item creation
    Window {
        id: invoiceWindow
        title: "Invoice - Order #" + orderId
        width: 600
        height: 800
        visible: false
        flags: Qt.Dialog | Qt.WindowCloseButtonHint

        // Properties to store invoice data
        property int orderId: -1
        property var orderDetails: ({})
        property string customerName: ""
        property string customerPhone: ""
        property var orderItems: []
        property int discountAmount: 0
        property real totalAmount: 0
        property real discountedTotal: 0
        property string paymentMethod: "Cash"

        // Function to generate invoice content
        function generateInvoiceContent() {
            console.log("Generating invoice content...");
            console.log("Customer name: " + customerName);
            console.log("Customer phone: " + customerPhone);
            console.log("Payment method: " + paymentMethod);
            console.log("Total amount: " + totalAmount);
            console.log("Discount amount: " + discountAmount);
            console.log("Discounted total: " + discountedTotal);
            console.log("Order items count: " + (orderItems ? orderItems.length : 0));

            // Set model for order items
            orderItemsRepeater.model = orderItems;
        }

        Rectangle {
            anchors.fill: parent
            color: "white"

            // Invoice content
            Flickable {
                id: invoiceFlickable
                anchors.fill: parent
                anchors.bottom: closeButton.top
                anchors.bottomMargin: 10
                anchors.margins: 40
                contentWidth: width
                contentHeight: invoiceContent.height + 80
                clip: true

                ColumnLayout {
                    id: invoiceContent
                    width: parent.width
                    spacing: 20

                    // Company header
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: "PharmEase"
                            font.pixelSize: 30
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Pharmacy Management System"
                            font.pixelSize: 16
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "123 Main Street, Anytown, Pakistan"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Phone: +92-12345678 | Email: info@pharmease.com"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 2
                        color: "black"
                    }

                    // Invoice header
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "INVOICE"
                            font.pixelSize: 24
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // Invoice and customer details
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // Left side - Invoice details
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    text: "Date: " + Qt.formatDateTime(new Date(), "dd-MM-yyyy")
                                    font.pixelSize: 14
                                }

                                Text {
                                    text: "Invoice #: INV-" + invoiceWindow.orderId
                                    font.pixelSize: 14
                                }

                                Text {
                                    // Fixed payment method display
                                    text: "Payment Method: " + invoiceWindow.paymentMethod
                                    font.pixelSize: 14
                                }
                            }

                            Text {
                                text: "Customer Details:"
                                font.pixelSize: 14
                                font.bold: true
                                Layout.alignment: Qt.AlignRight
                            }
                        }

                        // Customer details in second row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // Empty space on left side
                            Item { Layout.fillWidth: true }

                            // Right side - Customer details
                            ColumnLayout {
                                Layout.alignment: Qt.AlignRight
                                spacing: 5

                                Text {
                                    text: "Name: " + invoiceWindow.customerName
                                    font.pixelSize: 14
                                    Layout.alignment: Qt.AlignRight
                                }

                                Text {
                                    text: "Phone: " + invoiceWindow.customerPhone
                                    font.pixelSize: 14
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }
                    }

                    // Order items header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: "#e0e0e0"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: 5

                            Text {
                                text: "Item"
                                font.bold: true
                                Layout.preferredWidth: parent.width * 0.4
                            }

                            Text {
                                text: "Qty"
                                font.bold: true
                                Layout.preferredWidth: parent.width * 0.15
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                text: "Unit Price"
                                font.bold: true
                                Layout.preferredWidth: parent.width * 0.2
                                horizontalAlignment: Text.AlignRight
                            }

                            Text {
                                text: "Total"
                                font.bold: true
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    // Order items - Using Repeater
                    Column {
                        Layout.fillWidth: true
                        spacing: 0

                        Repeater {
                            id: orderItemsRepeater
                            model: []  // Will be set in generateInvoiceContent

                            delegate: Rectangle {
                                width: invoiceContent.width
                                height: 35
                                color: index % 2 === 0 ? "#f8f8f8" : "white"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    spacing: 5

                                    Text {
                                        text: modelData.name
                                        Layout.preferredWidth: parent.width * 0.4
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.quantity
                                        Layout.preferredWidth: parent.width * 0.15
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        text: "Rs. " + modelData.price
                                        Layout.preferredWidth: parent.width * 0.2
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    Text {
                                        text: "Rs. " + (modelData.price * modelData.quantity)
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }

                        // Show message if no items
                        Rectangle {
                            width: invoiceContent.width
                            height: 35
                            color: "#f8f8f8"
                            visible: orderItemsRepeater.count === 0

                            Text {
                                anchors.centerIn: parent
                                text: "No items in this order"
                            }
                        }
                    }

                    // Totals
                    Rectangle {
                        Layout.fillWidth: true
                        height: 2
                        color: "black"
                    }

                    GridLayout {
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: 10
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 5

                        // Fixed subtotal display
                        Text {
                            text: "Subtotal:"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignRight
                        }

                        Text {
                            text: "Rs. " + invoiceWindow.totalAmount.toFixed(2)
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignRight
                        }

                        // Discount if applicable
                        Text {
                            text: "Discount (" + invoiceWindow.discountAmount + "%):"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignRight
                            visible: invoiceWindow.discountAmount > 0
                        }

                        Text {
                            text: "- Rs. " + (invoiceWindow.totalAmount * invoiceWindow.discountAmount / 100).toFixed(2)
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignRight
                            visible: invoiceWindow.discountAmount > 0
                        }

                        // Total payable amount
                        Text {
                            text: "Total Payable:"
                            font.pixelSize: 16
                            font.bold: true
                            Layout.alignment: Qt.AlignRight
                        }

                        Text {
                            text: "Rs. " + (invoiceWindow.discountAmount > 0 ? invoiceWindow.discountedTotal.toFixed(2) : invoiceWindow.totalAmount.toFixed(2))
                            font.pixelSize: 16
                            font.bold: true
                            Layout.alignment: Qt.AlignRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 2
                        color: "black"
                    }

                    // Terms and notes
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "Terms & Conditions:"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        Text {
                            text: "1. Medicines cannot be returned once purchased."
                            font.pixelSize: 12
                        }

                        Text {
                            text: "2. Please verify your purchase before leaving the counter."
                            font.pixelSize: 12
                        }

                        Text {
                            text: "3. Keep medicines out of reach of children."
                            font.pixelSize: 12
                        }

                        Text {
                            text: "Thank you for your purchase!"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 20
                        }
                    }
                }
            }

            // Close button at the bottom
            Button {
                id: closeButton
                text: "Close"
                width: 150
                height: 40
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 20
                onClicked: {
                    // Clear the form on close and update medicine stock
                    invoiceWindow.visible = false
                    messagePopup.text = "Order #" + orderId + " completed successfully!"
                    messagePopup.open()
                }
            }
        }

        // Update the content when window becomes visible
        onVisibleChanged: {
            if (visible) {
                generateInvoiceContent();
            }
        }
    }
    // Load medicines when component is created
    Component.onCompleted: {
        loadMedicines()
    }
}
