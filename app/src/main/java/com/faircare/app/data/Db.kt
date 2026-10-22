package com.faircare.app.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Plain SQLite store (no Room — keeps the build dependency-light). */
class Db private constructor(context: Context) {

    private val helper = object : SQLiteOpenHelper(context.applicationContext, "faircare.db", null, 1) {
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE babies(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, color INTEGER NOT NULL)")
            db.execSQL("CREATE TABLE caregivers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, type TEXT NOT NULL, color INTEGER NOT NULL)")
            db.execSQL("CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, emoji TEXT NOT NULL, weight REAL NOT NULL, eligibility TEXT NOT NULL, counts INTEGER NOT NULL, isCustom INTEGER NOT NULL, sort INTEGER NOT NULL)")
            db.execSQL("CREATE TABLE logs(id INTEGER PRIMARY KEY AUTOINCREMENT, babyId INTEGER NOT NULL, caregiverId INTEGER NOT NULL, taskId INTEGER NOT NULL, startMillis INTEGER NOT NULL, endMillis INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '')")
            db.execSQL("CREATE INDEX idx_logs_range ON logs(startMillis, endMillis)")
            db.execSQL("CREATE INDEX idx_logs_baby ON logs(babyId)")
        }

        override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) {}
    }

    // ---- babies ----
    fun getBabies(): List<Baby> = helper.readableDatabase.rawQuery(
        "SELECT id,name,color FROM babies ORDER BY id", null
    ).use { c ->
        buildList {
            while (c.moveToNext()) add(Baby(c.getLong(0), c.getString(1), c.getInt(2)))
        }
    }

    fun insertBaby(b: Baby): Long = helper.writableDatabase.insert("babies", null, ContentValues().apply {
        put("name", b.name); put("color", b.color)
    })

    fun deleteBaby(id: Long) {
        helper.writableDatabase.apply {
            delete("logs", "babyId=?", arrayOf(id.toString()))
            delete("babies", "id=?", arrayOf(id.toString()))
        }
    }

    // ---- caregivers ----
    fun getCaregivers(): List<Caregiver> = helper.readableDatabase.rawQuery(
        "SELECT id,name,type,color FROM caregivers ORDER BY id", null
    ).use { c ->
        buildList {
            while (c.moveToNext()) add(
                Caregiver(c.getLong(0), c.getString(1), CaregiverType.valueOf(c.getString(2)), c.getInt(3))
            )
        }
    }

    fun insertCaregiver(c: Caregiver): Long = helper.writableDatabase.insert("caregivers", null, ContentValues().apply {
        put("name", c.name); put("type", c.type.name); put("color", c.color)
    })

    fun deleteCaregiver(id: Long) {
        helper.writableDatabase.delete("caregivers", "id=?", arrayOf(id.toString()))
    }

    // ---- tasks ----
    fun getTasks(): List<CareTask> = helper.readableDatabase.rawQuery(
        "SELECT id,name,emoji,weight,eligibility,counts,isCustom,sort FROM tasks ORDER BY sort,id", null
    ).use { c ->
        buildList {
            while (c.moveToNext()) add(
                CareTask(
                    c.getLong(0), c.getString(1), c.getString(2), c.getFloat(3),
                    Eligibility.valueOf(c.getString(4)), c.getInt(5) == 1, c.getInt(6) == 1, c.getInt(7)
                )
            )
        }
    }

    fun insertTask(t: CareTask): Long = helper.writableDatabase.insert("tasks", null, ContentValues().apply {
        put("name", t.name); put("emoji", t.emoji); put("weight", t.weight)
        put("eligibility", t.eligibility.name); put("counts", if (t.countsTowardBalance) 1 else 0)
        put("isCustom", if (t.isCustom) 1 else 0); put("sort", t.sort)
    })

    fun updateTask(t: CareTask) {
        helper.writableDatabase.update("tasks", ContentValues().apply {
            put("name", t.name); put("emoji", t.emoji); put("weight", t.weight)
            put("eligibility", t.eligibility.name); put("counts", if (t.countsTowardBalance) 1 else 0)
        }, "id=?", arrayOf(t.id.toString()))
    }

    fun deleteTask(id: Long) {
        helper.writableDatabase.delete("tasks", "id=?", arrayOf(id.toString()))
    }

    // ---- logs ----
    fun getLogs(start: Long, end: Long, babyId: Long?): List<LogEntry> {
        val (sel, args) = if (babyId == null)
            "startMillis < ? AND endMillis > ?" to arrayOf(end.toString(), start.toString())
        else
            "babyId = ? AND startMillis < ? AND endMillis > ?" to arrayOf(babyId.toString(), end.toString(), start.toString())
        return helper.readableDatabase.rawQuery(
            "SELECT id,babyId,caregiverId,taskId,startMillis,endMillis,note FROM logs WHERE $sel ORDER BY startMillis",
            args
        ).use { c ->
            buildList {
                while (c.moveToNext()) add(
                    LogEntry(c.getLong(0), c.getLong(1), c.getLong(2), c.getLong(3), c.getLong(4), c.getLong(5), c.getString(6) ?: "")
                )
            }
        }
    }

    fun insertLog(e: LogEntry): Long = helper.writableDatabase.insert("logs", null, ContentValues().apply {
        put("babyId", e.babyId); put("caregiverId", e.caregiverId); put("taskId", e.taskId)
        put("startMillis", e.startMillis); put("endMillis", e.endMillis); put("note", e.note)
    })

    fun deleteLog(id: Long) {
        helper.writableDatabase.delete("logs", "id=?", arrayOf(id.toString()))
    }

    fun updateLog(e: LogEntry) {
        helper.writableDatabase.update("logs", ContentValues().apply {
            put("babyId", e.babyId); put("caregiverId", e.caregiverId); put("taskId", e.taskId)
            put("startMillis", e.startMillis); put("endMillis", e.endMillis); put("note", e.note)
        }, "id=?", arrayOf(e.id.toString()))
    }

    fun ensureSeeded() {
        if (getCaregivers().isEmpty()) {
            insertCaregiver(Caregiver(name = "Mom", type = CaregiverType.MOTHER, color = 0xFFE57373.toInt()))
            insertCaregiver(Caregiver(name = "Dad", type = CaregiverType.FATHER, color = 0xFF64B5F6.toInt()))
        }
        if (getTasks().isEmpty()) defaultTasks().forEach { insertTask(it) }
        if (getBabies().isEmpty()) insertBaby(Baby(name = "Baby", color = 0xFFFFD54F.toInt()))
    }

    companion object {
        @Volatile private var instance: Db? = null
        fun get(context: Context): Db =
            instance ?: synchronized(this) { instance ?: Db(context).also { instance = it } }
    }
}

/** Default tasks with the fairness rules baked in. Weight = effort multiplier. */
fun defaultTasks(): List<CareTask> = listOf(
    CareTask(name = "Breastfeeding", emoji = "\uD83E\uDD31", weight = 1.5f, eligibility = Eligibility.MOTHER_ONLY, sort = 0),
    CareTask(name = "Pumping", emoji = "\uD83D\uDCA6", weight = 1.5f, eligibility = Eligibility.MOTHER_ONLY, sort = 1),
    CareTask(name = "Bottle feed", emoji = "\uD83C\uDF7C", weight = 1.0f, sort = 2),
    CareTask(name = "Diaper change", emoji = "\uD83D\uDCA9", weight = 1.0f, sort = 3),
    CareTask(name = "Bath", emoji = "\uD83D\uDEC1", weight = 1.2f, sort = 4),
    CareTask(name = "Bedtime routine", emoji = "\uD83C\uDF19", weight = 1.2f, sort = 5),
    CareTask(name = "Night soothing", emoji = "\uD83D\uDE34", weight = 1.5f, sort = 6),
    CareTask(name = "Playtime", emoji = "\uD83E\uDDF8", weight = 0.8f, sort = 7),
    CareTask(name = "Doctor visit", emoji = "\uD83C\uDFE5", weight = 2.0f, sort = 8),
    CareTask(name = "Solids / meal prep", emoji = "\uD83E\uDD63", weight = 1.0f, sort = 9),
    CareTask(name = "Baby laundry", emoji = "\uD83E\uDDFa", weight = 0.8f, sort = 10),
    CareTask(name = "On-duty supervising", emoji = "\uD83D\uDC40", weight = 0.7f, sort = 11),
)
