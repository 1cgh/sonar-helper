Перем Лог;

Перем Токен;
Перем АдресСервера;
Перем РодительскийПроект;
Перем ДочерниеПроекты;
Перем ИсключаемыеПроекты;
Перем Статусы;
Перем ИзEDTВКонфигуратор;

///////////////////////////////////////////////////////////////////////////////////////////////////
// Прикладной интерфейс
///////////////////////////////////////////////////////////////////////////////////////////////////

Процедура ЗарегистрироватьКоманду(Знач ИмяКоманды, Знач Парсер) Экспорт
	
	ОписаниеКоманды = Парсер.ОписаниеКоманды(ИмяКоманды, "Выполняет закрытие замечаний (как не требующих исправление) из родительского проекта в дочерних");
	Парсер.ДобавитьИменованныйПараметрКоманды(ОписаниеКоманды, "--token", "Токен для авторизации на сервере SonarQube");
	Парсер.ДобавитьИменованныйПараметрКоманды(ОписаниеКоманды, "--server", "Адрес сервера SonarQube (например http://my.sonar.server:9000)");
	Парсер.ДобавитьИменованныйПараметрКоманды(ОписаниеКоманды, "--parent-project", "Ключ родительского проекта (например bsp:master)");
	Парсер.ДобавитьИменованныйПараметрКоманды(ОписаниеКоманды, "--child-projects", "Ключи дочерних проектов, строкой через запятую (например hrm:develop,buh:master).
	|	Для того, чтобы указать все проекты, необходимо передать #all");
	Парсер.ДобавитьИменованныйПараметрКоманды(ОписаниеКоманды, "--exclude-projects", "Ключи дочерних проектов, которые необходимо исключить из обработки");
	Парсер.ДобавитьИменованныйПараметрКоманды(ОписаниеКоманды, "--statuses", "Отбор замечаний родительского проекта только соответствующих статусов.
	|	Необходимые статусы необходимо передавать строкой через запятую.
	|	Возможные значения:
	|		OPEN - открытые
	|		CONFIRMED - подтвержденные:
	|		REOPENED - переоткрытые
	|		RESOLVED - решенные
	|		CLOSED - закрытые
	|	
	|	По умолчанию выбираются только RESOLVED и CLOSED");
	Парсер.ДобавитьПараметрФлагКоманды(ОписаниеКоманды, "--edt2cfg", "Необходимо использовать тогда, когда родительский проект в формате EDT, а дочерний в формате конфигуратора");
	Парсер.ДобавитьИменованныйПараметрКоманды(ОписаниеКоманды, "--cfg-file", "Путь к конфигурационному файлу в формате json (utf-8), свойства объекта соответствуют ключам запуска.
	|	Пример конфигурационного файла находится в каталоге examples");
	
	Парсер.ДобавитьКоманду(ОписаниеКоманды);
	
КонецПроцедуры

// Выполняет логику команды
// 
// Параметры:
//   ПараметрыКоманды - Соответствие - Соответствие ключей командной строки и их значений
//   ДополнительныеПараметры - Соответствие -  (необязательно) дополнительные параметры
//
Функция ВыполнитьКоманду(Знач ПараметрыКоманды, Знач ДополнительныеПараметры = Неопределено) Экспорт
	
	Лог = ДополнительныеПараметры.Лог;
	ОшибокНет = ПрочитатьПараметрыЗапуска(ПараметрыКоманды);
	Если НЕ ОшибокНет Тогда
		Возврат СообщитьОбОшибке("Ошибка запуска");
	КонецЕсли;

	Лог.Информация("Получение информации о проектах");
	ПроектыSQ = Сонар.ПолучитьПроекты(АдресСервера, Токен);
	Лог.Информация("Получение информации о родительском проекте");
	ОписаниеРодительскогоПроекта = ПроектыSQ.Получить(РодительскийПроект);
	Если ОписаниеРодительскогоПроекта = Неопределено Тогда
		Возврат СообщитьОбОшибке(СтрШаблон("Родительский проект `%1` в списке проектов не обнаружен", РодительскийПроект));
	КонецЕсли;
	
	Лог.Информация("Получение закрываемых замечаний из родительского проекта");
	ЗамечанияРодительскогоПроекта = Сонар.ПолучитьЗамечанияПроекта(
										АдресСервера, Токен, 
										ОписаниеРодительскогоПроекта,
										Статусы,
										ИзEDTВКонфигуратор);

	Если НЕ ЗамечанияРодительскогоПроекта.Количество() Тогда
		
		Лог.Информация("Закрываемых замечаний в родительском проекте нет");
		Возврат МенеджерКомандПриложения.РезультатыКоманд().Успех;

	КонецЕсли;
		
	Если ДочерниеПроекты.Найти("#all") <> Неопределено Тогда
		ДочерниеПроекты.Очистить();
		Для Каждого ОписаниеПроекта Из ПроектыSQ Цикл
			Если ОписаниеПроекта.Ключ <> РодительскийПроект Тогда
				ДочерниеПроекты.Добавить(ОписаниеПроекта.Ключ);
			КонецЕсли;
		КонецЦикла;
	КонецЕсли;
		
	Для Каждого ИсключаемыйПроект Из ИсключаемыеПроекты Цикл
		Позиция = ДочерниеПроекты.Найти(СокрЛП(ИсключаемыйПроект));
		Если Позиция <> Неопределено Тогда
			ДочерниеПроекты.Удалить(Позиция);
		КонецЕсли;
	КонецЦикла;
	
	Лог.Информация("Закрытие замечаний в дочерних проектах");
	Для Каждого ДочернийПроект Из ДочерниеПроекты Цикл
		Лог.Информация("Закрытие замечаний в  проекте `%1`", ДочернийПроект);
		ОписаниеПроекта = ПроектыSQ.Получить(СокрЛП(ДочернийПроект));
		Если ОписаниеПроекта = Неопределено Тогда
			Лог.Ошибка("Проект `%1` не обнаружен", ДочернийПроект);
			Продолжить;
		КонецЕсли;

		ЗакрываемыеЗамечания = Сонар.ПолучитьЗакрываемыеЗамечания(АдресСервера, Токен, ОписаниеПроекта, ЗамечанияРодительскогоПроекта);
		Если ЗакрываемыеЗамечания.Количество() Тогда
			Лог.Информация("Для проекта `%1` будет закрыто замечаний: `%2` ", ДочернийПроект, ЗакрываемыеЗамечания.Количество());
			Сонар.ЗакрытьЗамечания(АдресСервера, Токен, ЗакрываемыеЗамечания, "Привнесено '" + РодительскийПроект + "'");
		КонецЕсли;
	КонецЦикла;
	
	Возврат МенеджерКомандПриложения.РезультатыКоманд().Успех;

КонецФункции

///////////////////////////////////////////////////////////////////////////////////////////////////

Функция ПрочитатьПараметрыЗапуска(ПараметрыКоманды)
	
	ОшибокНет = Истина;

	Токен = ПараметрыКоманды["--token"];
	АдресСервера = ПараметрыКоманды["--server"];
	РодительскийПроект = ПараметрыКоманды["--parent-project"];
	ДочерниеПроектыСтрокой = ПараметрыКоманды["--child-projects"];
	ИсключаемыеПроектыСтрокой = ПараметрыКоманды["--exclude-projects"];
	СтатусыСтрокой = ПараметрыКоманды["--statuses"];
	ИзEDTВКонфигуратор = ПараметрыКоманды["--edt2cfg"];

	ПутьККонфигурационномуФайлу = ПараметрыКоманды["--cfg-file"];
	Если ПутьККонфигурационномуФайлу <> Неопределено Тогда
		
		Файл = Новый Файл(ПутьККонфигурационномуФайлу);
		Если Файл.Существует() Тогда
			ТекстовыйДокумент = Новый ТекстовыйДокумент();
			ТекстовыйДокумент.Прочитать(ПутьККонфигурационномуФайлу);
			Лог.Отладка("Содержимое конфигурационного файла: %1%2", Символы.ПС, ТекстовыйДокумент.ПолучитьТекст());
			JSON = Новый ЧтениеJSON();
			JSON.УстановитьСтроку(ТекстовыйДокумент.ПолучитьТекст());
			ПараметрыИзФайла = ПрочитатьJSON(JSON, Истина);
			Если Токен = Неопределено Тогда
				Токен = ПараметрыИзФайла.Получить("--token");
			КонецЕсли;
			Если АдресСервера = Неопределено Тогда
				АдресСервера = ПараметрыИзФайла.Получить("--server");
			КонецЕсли;
			Если РодительскийПроект = Неопределено Тогда
				РодительскийПроект = ПараметрыИзФайла.Получить("--parent-project");
			КонецЕсли;
			Если ДочерниеПроектыСтрокой = Неопределено Тогда
				ДочерниеПроектыСтрокой = ПараметрыИзФайла.Получить("--child-projects");
			КонецЕсли;
			Если ИсключаемыеПроектыСтрокой = Неопределено Тогда
				ИсключаемыеПроектыСтрокой = ПараметрыИзФайла.Получить("--exclude-projects");
			КонецЕсли;
			Если СтатусыСтрокой = Неопределено Тогда
				СтатусыСтрокой = ПараметрыИзФайла.Получить("--statuses");
			КонецЕсли;
			Если ИзEDTВКонфигуратор = Ложь И ПараметрыИзФайла.Получить("--edt2cfg") <> Неопределено Тогда
				ИзEDTВКонфигуратор = ПараметрыИзФайла.Получить("--edt2cfg");
			КонецЕсли;
		Иначе
			Лог.Ошибка("Конфигурационный файл по пути `%1` не обнаружен", ОбернутьЗначениеДляПечати(ПутьККонфигурационномуФайлу));
			ОшибокНет = Ложь;
		КонецЕсли;
		
	КонецЕсли;
	
	Лог.Отладка("Прочитанные параметры:");
	Лог.Отладка("	Токен = `%1`", ОбернутьЗначениеДляПечати(Токен));
	Лог.Отладка("	Адрес сервера = `%1`", ОбернутьЗначениеДляПечати(АдресСервера));
	Лог.Отладка("	Ключ родительского проекта = `%1`", ОбернутьЗначениеДляПечати(РодительскийПроект));
	Лог.Отладка("	Ключ дочерних проектов (строкой) = `%1`", ОбернутьЗначениеДляПечати(ДочерниеПроектыСтрокой));
	Лог.Отладка("	Ключ исключаемых проектов (строкой) = `%1`", ОбернутьЗначениеДляПечати(ИсключаемыеПроектыСтрокой));
	Лог.Отладка("	Статусы строкой = `%1`", ОбернутьЗначениеДляПечати(СтатусыСтрокой));
	Лог.Отладка("	Нужно переводить из EDT = `%1`", ОбернутьЗначениеДляПечати(ИзEDTВКонфигуратор));

	Если Не ЗначениеЗаполнено(Токен) Тогда
		Лог.Ошибка("Не указан токен для авторизации");
		ОшибокНет = Ложь;
	КонецЕсли;
	
	Если Не ЗначениеЗаполнено(АдресСервера) Тогда
		Лог.Ошибка("Не указан адрес сервера SonarQube");
		ОшибокНет = Ложь;
	КонецЕсли;

	Если Не ЗначениеЗаполнено(РодительскийПроект) Тогда
		Лог.Ошибка("Не указан ключ родительского проекта");
		ОшибокНет = Ложь;
	КонецЕсли;

	Если Не ЗначениеЗаполнено(ДочерниеПроектыСтрокой) Тогда
		Лог.Ошибка("Не указаны ключ дочерних проектов");
		ОшибокНет = Ложь;
	Иначе
		ДочерниеПроекты = СтрРазделить(ДочерниеПроектыСтрокой, ",", Ложь);
	КонецЕсли;

	ИсключаемыеПроекты = Новый Массив();
	Если ЗначениеЗаполнено(ИсключаемыеПроектыСтрокой) Тогда
		ИсключаемыеПроекты = СтрРазделить(ИсключаемыеПроектыСтрокой, ",", Ложь);
	КонецЕсли;
	ИсключаемыеПроекты.Добавить(СокрЛП(РодительскийПроект));

	Если Не ЗначениеЗаполнено(СтатусыСтрокой) Тогда
		Статусы = СтрРазделить("RESOLVED,CLOSED", ",", Ложь);
	Иначе
		Статусы = СтрРазделить(СтатусыСтрокой, ",", Ложь);
	КонецЕсли;
	
	Возврат ОшибокНет;
	
КонецФункции

Функция ОбернутьЗначениеДляПечати(Знач Значение)
	Если ЗначениеЗаполнено(Значение) Тогда
		Возврат Строка(Значение);
	КонецЕсли;
	Возврат "<Незаполнено>";
КонецФункции

Функция СообщитьОбОшибке(ТекстОшибки)
	
	Лог.Ошибка(ТекстОшибки);
	Возврат МенеджерКомандПриложения.РезультатыКоманд().ОшибкаВремениВыполнения;

КонецФункции
