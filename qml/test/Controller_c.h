/*
 * Generated at 2013-05-09 12:56:37.800282+04:00
 */
#ifndef Controller_c_H
#define Controller_c_H
#include "kamlo.h"
#include <QtCore/QDebug>
#include <QtCore/QObject>

class Controller: public QObject {
  Q_OBJECT
  value _camlobjHolder;
public:
  Controller();
  void storeCAMLobj(value x) {
    if (_camlobjHolder != 0) {
       //maybe unregister global root?
    }
    _camlobjHolder = x;
    register_global_root(&_camlobjHolder);
  }
  Q_INVOKABLE void onItemSelected(int,int);
  Q_INVOKABLE void setPaths(QList<QString>);
  Q_INVOKABLE QList<QString> paths();
  Q_INVOKABLE QString getFullPath();
public:
  Q_PROPERTY(bool hasData  READ isHasData NOTIFY hasDataChanged)
  Q_INVOKABLE bool isHasData();
signals:
  void hasDataChanged(bool);
public:
  void emit_hasDataChanged(bool arg1) {
    emit hasDataChanged(arg1);
  }

public:
  Q_PROPERTY(QString descr  READ getDescr NOTIFY descChanged)
  Q_INVOKABLE QString getDescr();
signals:
  void descChanged(QString);
public:
  void emit_descChanged(QString arg1) {
    emit descChanged(arg1);
  }

};
#endif // Controller_H
