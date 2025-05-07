#include "customer.h"
#include "databasemanager.h"

Customer::Customer(DatabaseManager* dbManager, int id, const QString &name, const QString &contact)
    : db(dbManager), customer_id(id), name(name), contact_no(contact){}

Customer::Customer(DatabaseManager* dbManager) : db(dbManager), customer_id(0), name(""), contact_no("") {}

