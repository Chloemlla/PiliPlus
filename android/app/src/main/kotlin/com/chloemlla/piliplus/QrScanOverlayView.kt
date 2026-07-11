package com.chloemlla.piliplus

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View
import kotlin.math.min

internal class QrScanOverlayView(context: Context) : View(context) {
    private val shadePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x99000000.toInt()
        style = Paint.Style.FILL
    }
    private val framePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        strokeWidth = 4f * resources.displayMetrics.density
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val cutout = RectF()
    private val shadePath = Path()

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val size = min(width, height) * 0.68f
        val left = (width - size) / 2f
        val top = (height - size) / 2f
        cutout.set(left, top, left + size, top + size)

        shadePath.reset()
        shadePath.fillType = Path.FillType.EVEN_ODD
        shadePath.addRect(0f, 0f, width.toFloat(), height.toFloat(), Path.Direction.CW)
        shadePath.addRoundRect(cutout, 24f, 24f, Path.Direction.CW)
        canvas.drawPath(shadePath, shadePaint)

        val corner = size * 0.16f
        drawCorner(canvas, left, top, corner, 1f, 1f)
        drawCorner(canvas, cutout.right, top, corner, -1f, 1f)
        drawCorner(canvas, left, cutout.bottom, corner, 1f, -1f)
        drawCorner(canvas, cutout.right, cutout.bottom, corner, -1f, -1f)
    }

    private fun drawCorner(
        canvas: Canvas,
        x: Float,
        y: Float,
        length: Float,
        horizontal: Float,
        vertical: Float,
    ) {
        canvas.drawLine(x, y, x + length * horizontal, y, framePaint)
        canvas.drawLine(x, y, x, y + length * vertical, framePaint)
    }
}

